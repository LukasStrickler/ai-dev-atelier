import { generateFilename, downloadImage, type Mode, type TierLabel } from "./utils";
import type { ProviderResult, ErrorCode } from "../types";

interface QueueSubmitResponse {
  request_id: string;
  status_url: string;
  response_url: string;
  error?: string;
  detail?: string;
  message?: string;
}

interface QueueStatusResponse {
  status: "IN_QUEUE" | "IN_PROGRESS" | "COMPLETED" | string;
  queue_position?: number;
  logs?: Array<{ message: string; timestamp: string }>;
  error?: string;
}

interface FalImageResult {
  images?: Array<{
    url: string;
    width: number;
    height: number;
    content_type: string;
  }>;
  image?: {
    url: string;
    width: number;
    height: number;
    content_type: string;
  };
}

export interface FalInput {
  prompt?: string;
  image_url?: string;
  image_urls?: string[];
  mask_url?: string;
  image_size?: { width: number; height: number };
  [key: string]: unknown;
}

function getFalKey(): string | null {
  return process.env.FAL_KEY || process.env.FAL_API_KEY || null;
}

function handleFalHttpError(status: number, errText: string): ProviderResult {
  const errLower = errText.toLowerCase();

  if (status === 401) {
    console.error(`
❌ Fal.ai API key is invalid

Fix: Check FAL_API_KEY in your .env file
Get key: https://fal.ai/dashboard/keys
`);
    return {
      success: false,
      error: "Fal.ai API key is invalid. Check FAL_API_KEY in .env",
      code: "FAL_AUTH_INVALID" as ErrorCode,
    };
  }

  if (status === 402 || errLower.includes("credits") || errLower.includes("insufficient") || errLower.includes("balance")) {
    console.error(`
❌ Fal.ai credits exhausted

Fix: Add credits at https://fal.ai/dashboard
`);
    return {
      success: false,
      error: "Fal.ai credits exhausted. Add credits at: https://fal.ai/dashboard",
      code: "FAL_CREDITS_EXHAUSTED" as ErrorCode,
    };
  }

  if (status === 429) {
    console.error(`
❌ Fal.ai rate limit exceeded

Fix: Wait 60 seconds and retry
`);
    return {
      success: false,
      error: "Fal.ai rate limit exceeded. Wait 60 seconds and retry.",
      code: "FAL_RATE_LIMIT" as ErrorCode,
    };
  }

  return {
    success: false,
    error: `Fal.ai error (${status}): ${errText}`,
    code: "FAL_ERROR" as ErrorCode,
  };
}

export async function falQueue(
  model: string,
  input: FalInput,
  outputDir?: string,
  filenameHint?: string,
  mode?: Mode,
  tier?: TierLabel
): Promise<ProviderResult> {
  const FAL_KEY = getFalKey();

  if (!FAL_KEY) {
    console.error(`
❌ Fal.ai API key not configured

Fix: Add to your .env file:
  FAL_API_KEY=your_api_key

Get key: https://fal.ai/dashboard/keys
Docs: references/usage-guide.md#error-recovery
`);
    return {
      success: false,
      error: "Missing FAL_API_KEY in .env",
      code: "FAL_AUTH_INVALID" as ErrorCode,
    };
  }

  const SUBMIT_URL = `https://queue.fal.run/${model}`;
  const MAX_POLL_ATTEMPTS = 120;

  console.log(`   Fal.ai: ${model}...`);

  try {
    const submitRes = await fetch(SUBMIT_URL, {
      method: "POST",
      headers: {
        Authorization: `Key ${FAL_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(input),
    });

    if (!submitRes.ok) {
      const errText = await submitRes.text();
      return handleFalHttpError(submitRes.status, errText);
    }

    const job = (await submitRes.json()) as QueueSubmitResponse;
    const { request_id, status_url, response_url } = job;

    if (!request_id) {
      return {
        success: false,
        error: `No request_id in response: ${JSON.stringify(job)}`,
        code: "FAL_ERROR" as ErrorCode,
      };
    }

    console.log(`   Queued (${request_id})...`);

    let isCompleted = false;
    let pollCount = 0;

    while (!isCompleted && pollCount < MAX_POLL_ATTEMPTS) {
      pollCount++;
      const statusRes = await fetch(status_url, {
        headers: { Authorization: `Key ${FAL_KEY}` },
      });

      if (!statusRes.ok) {
        return handleFalHttpError(statusRes.status, await statusRes.text());
      }

      const statusData = (await statusRes.json()) as QueueStatusResponse;
      const { status } = statusData;

      if (status === "COMPLETED") {
        isCompleted = true;
      } else if (status === "IN_QUEUE" || status === "IN_PROGRESS") {
        await new Promise((resolve) => setTimeout(resolve, 1000));
      } else {
        return {
          success: false,
          error: `Job failed: ${statusData.error || status}`,
          code: "FAL_ERROR" as ErrorCode,
        };
      }
    }

    if (!isCompleted) {
      console.error(`
❌ Fal.ai job timed out after ${MAX_POLL_ATTEMPTS} seconds

Fix: Try again or use a faster tier
`);
      return {
        success: false,
        error: `Job timed out after ${MAX_POLL_ATTEMPTS}s`,
        code: "FAL_JOB_TIMEOUT" as ErrorCode,
      };
    }

    const resultRes = await fetch(response_url, {
      headers: { Authorization: `Key ${FAL_KEY}` },
    });

    if (!resultRes.ok) {
      return handleFalHttpError(resultRes.status, await resultRes.text());
    }

    const resultData = (await resultRes.json()) as FalImageResult;
    const imageUrl = resultData.images?.[0]?.url || resultData.image?.url;

    if (!imageUrl) {
      console.error("   No image URL in response");
      return {
        success: false,
        error: "No image URL in Fal.ai response",
        code: "FAL_NO_IMAGE" as ErrorCode,
      };
    }

    const ext = imageUrl.includes(".webp")
      ? "webp"
      : imageUrl.includes(".svg")
        ? "svg"
        : "jpg";
    const filename = generateFilename(filenameHint || "image", ext, mode, tier);
    const filepath = outputDir ? `${outputDir}/${filename}` : filename;

    await downloadImage(imageUrl, filepath);

    return { success: true, filePath: filepath };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`   Fal.ai failed: ${message}`);
    return { success: false, error: message, code: "FAL_ERROR" as ErrorCode };
  }
}

export async function imageToDataUrl(imagePath: string): Promise<string> {
  const file = Bun.file(imagePath);
  const buffer = await file.arrayBuffer();
  const base64 = Buffer.from(buffer).toString("base64");
  const mimeType = file.type || "image/png";
  return `data:${mimeType};base64,${base64}`;
}

export async function uploadToFal(imagePath: string): Promise<string> {
  if (imagePath.startsWith("http://") || imagePath.startsWith("https://")) {
    return imagePath;
  }

  const FAL_KEY = getFalKey();
  if (!FAL_KEY) {
    throw new Error("FAL_API_KEY required for file upload");
  }

  const file = Bun.file(imagePath);
  const buffer = await file.arrayBuffer();
  const contentType = file.type || "image/png";
  const fileName = imagePath.split("/").pop() || "image.png";

  const initiateRes = await fetch(
    "https://rest.alpha.fal.ai/storage/upload/initiate",
    {
      method: "POST",
      headers: {
        Authorization: `Key ${FAL_KEY}`,
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        file_name: fileName,
        content_type: contentType,
      }),
    }
  );

  if (!initiateRes.ok) {
    throw new Error(`Upload initiate failed: ${await initiateRes.text()}`);
  }

  const { upload_url, file_url } = (await initiateRes.json()) as {
    upload_url: string;
    file_url: string;
  };

  const uploadRes = await fetch(upload_url, {
    method: "PUT",
    headers: { "Content-Type": contentType },
    body: buffer,
  });

  if (!uploadRes.ok) {
    throw new Error(`Upload failed: ${uploadRes.status}`);
  }

  return file_url;
}
