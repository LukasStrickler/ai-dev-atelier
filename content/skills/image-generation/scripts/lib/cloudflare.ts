import { generateFilename } from "./utils";
import type { ProviderResult, ErrorCode } from "../types";

export async function generateCloudflare(
  prompt: string,
  width: number = 1024,
  height: number = 1024,
  outputDir?: string
): Promise<ProviderResult> {
  const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
  const apiToken = process.env.CLOUDFLARE_API_TOKEN;

  if (!accountId || !apiToken) {
    const missing = !accountId ? "CLOUDFLARE_ACCOUNT_ID" : "CLOUDFLARE_API_TOKEN";
    console.error(`
❌ Cloudflare API keys not configured

Missing: ${missing}

Fix: Add to your .env file:
  CLOUDFLARE_ACCOUNT_ID=your_account_id
  CLOUDFLARE_API_TOKEN=your_api_token

Get keys: https://dash.cloudflare.com/profile/api-tokens
Docs: references/usage-guide.md#error-recovery
`);
    return {
      success: false,
      error: `Missing ${missing}`,
      code: "CF_AUTH_MISSING" as ErrorCode,
    };
  }

  const model = "@cf/black-forest-labs/flux-2-klein-4b";
  const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/run/${model}`;

  console.log(`   Cloudflare: flux-2-klein (FREE)...`);

  try {
    const formData = new FormData();
    formData.append("prompt", prompt);
    formData.append("width", String(width));
    formData.append("height", String(height));
    formData.append("steps", "25");

    const response = await fetch(url, {
      method: "POST",
      headers: { Authorization: `Bearer ${apiToken}` },
      body: formData,
    });

    if (response.status === 429) {
      console.error(`
❌ Cloudflare rate limit exceeded

Info: FREE tier limited to ~96 images/day
Fix:
  1. Wait until tomorrow (resets at midnight UTC)
  2. Use default tier: bun scripts/gen.ts "prompt" -t default

Docs: references/usage-guide.md#tier-selection
`);
      return {
        success: false,
        error: "Cloudflare rate limit exceeded (~96/day). Wait until midnight UTC or use default tier.",
        code: "CF_RATE_LIMIT" as ErrorCode,
      };
    }

    if (!response.ok) {
      const errText = await response.text();
      const errLower = errText.toLowerCase();

      if (errLower.includes("quota") || errLower.includes("limit") || errLower.includes("exceeded")) {
        console.error(`
❌ Cloudflare FREE quota exceeded for today

Info: ~96 images/day limit reached
Fix:
  1. Wait until tomorrow (resets at midnight UTC)
  2. Use default tier: bun scripts/gen.ts "prompt" -t default

Docs: references/usage-guide.md#tier-selection
`);
        return {
          success: false,
          error: "Cloudflare quota exceeded. Wait until midnight UTC or use default tier.",
          code: "CF_QUOTA_EXCEEDED" as ErrorCode,
        };
      }

      if (response.status === 401 || response.status === 403) {
        console.error(`
❌ Cloudflare authentication failed

Fix: Check your API token has Workers AI permissions
Get keys: https://dash.cloudflare.com/profile/api-tokens
`);
        return {
          success: false,
          error: `Cloudflare auth error (${response.status}): ${errText}`,
          code: "CF_AUTH_MISSING" as ErrorCode,
        };
      }

      return {
        success: false,
        error: `Cloudflare API error (${response.status}): ${errText}`,
        code: "CF_ERROR" as ErrorCode,
      };
    }

    const data = (await response.json()) as { result?: { image?: string }; success: boolean };

    if (!data.success || !data.result?.image) {
      return {
        success: false,
        error: "No image in Cloudflare response",
        code: "CF_ERROR" as ErrorCode,
      };
    }

    const imageBuffer = Buffer.from(data.result.image, "base64");
    const filename = generateFilename(prompt, "png", "gen", "iterate");
    const filepath = outputDir ? `${outputDir}/${filename}` : filename;

    await Bun.write(filepath, imageBuffer);
    console.log(`✅ Saved to ${filepath}`);

    return { success: true, filePath: filepath };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`   Cloudflare failed: ${message}`);
    return { success: false, error: message, code: "CF_ERROR" as ErrorCode };
  }
}
