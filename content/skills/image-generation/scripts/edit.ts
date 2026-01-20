#!/usr/bin/env bun
import { parseArgs } from "util";
import { mkdirSync } from "fs";
import { join } from "path";
import { loadEnv, findRepoRoot } from "./lib/env";
import { falQueue, uploadToFal } from "./lib/fal-client";
import { EDIT_MODELS, PRICING, parseSize, parseTier } from "./lib/config";

loadEnv();

const repoRoot = findRepoRoot(import.meta.dir) || process.cwd();
const OUTPUT_DIR = join(repoRoot, ".ada", "data", "images");
mkdirSync(OUTPUT_DIR, { recursive: true });

const { values, positionals } = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    tier: { type: "string", short: "t", default: "default" },
    size: { type: "string", short: "s", default: "1024x1024" },
    mask: { type: "string", short: "m" },
    ref: { type: "string", multiple: true },
    help: { type: "boolean", short: "h", default: false },
  },
  allowPositionals: true,
});

if (values.help || positionals.length < 2) {
  console.log(`Usage: bun edit.ts <image> <instruction> [options]

Arguments:
  <image>        Path to source image (local file or URL)
  <instruction>  Edit instruction (e.g., "make the sky purple")

Options:
  -t, --tier <tier>  Quality tier: iterate|default|premium|max (default: default)
  -s, --size WxH     Output size (default: 1024x1024)
  -m, --mask <path>  Mask image for inpainting (white = edit area)
  --ref <path>       Reference image(s) for style/composition (can repeat)
  -h, --help         Show help

Tiers:
  iterate   Quick edits, cheap          ${PRICING.edit.iterate}
  default   Daily driver, best value    ${PRICING.edit.default}
  premium   High quality edits          ${PRICING.edit.premium}
  max       Multi-ref, heavy control    ${PRICING.edit.max}

Note: --ref triggers max tier (flux-2-flex) for multi-reference composition.

Examples:
  bun edit.ts photo.jpg "make it sunset"
  bun edit.ts photo.jpg "remove background" -t premium
  bun edit.ts photo.jpg "add hat" --mask mask.png
  bun edit.ts photo.jpg "match this style" --ref style.jpg --ref style2.jpg
`);
  process.exit(0);
}

const imagePath = positionals[0];
const instruction = positionals.slice(1).join(" ");
const references = values.ref || [];
const tier = references.length >= 2 ? "max" : parseTier(values.tier);
const { width, height } = parseSize(values.size || "1024x1024");

async function main() {
  const model = EDIT_MODELS[tier];
  const pricing = PRICING.edit[tier];

  console.log(`   [${tier.toUpperCase()}] ${pricing}`);

  const imageUrl = await uploadToFal(imagePath);

  const input: Record<string, unknown> = {
    image_urls: [imageUrl],
    prompt: instruction,
  };

  if (values.mask) {
    input.mask_url = await uploadToFal(values.mask);
  }

  if (references.length > 0) {
    const refUrls = await Promise.all(references.map(uploadToFal));
    input.image_urls = [imageUrl, ...refUrls];
  }

  const result = await falQueue(model, input, OUTPUT_DIR, instruction, "edit", tier);

  if (!result.success) {
    process.exit(1);
  }

  console.log(`   Done: ${result.filePath}`);
}

main().catch((err) => {
  console.error(`Error: ${err.message}`);
  process.exit(1);
});
