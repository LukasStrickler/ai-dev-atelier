#!/usr/bin/env bun
import { parseArgs } from "util";
import { mkdirSync } from "fs";
import { join } from "path";
import { loadEnv, findRepoRoot } from "./lib/env";
import { falQueue, uploadToFal } from "./lib/fal-client";
import { UPSCALE_MODELS, PRICING, parseTier } from "./lib/config";

loadEnv();

const repoRoot = findRepoRoot(import.meta.dir) || process.cwd();
const OUTPUT_DIR = join(repoRoot, ".ada", "data", "images");
mkdirSync(OUTPUT_DIR, { recursive: true });

const { values, positionals } = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    tier: { type: "string", short: "t", default: "default" },
    scale: { type: "string", default: "2" },
    help: { type: "boolean", short: "h", default: false },
  },
  allowPositionals: true,
});

if (values.help || positionals.length === 0) {
  console.log(`Usage: bun upscale.ts <image> [options]

Arguments:
  <image>  Path to source image (local file or URL)

Options:
  -t, --tier <tier>  Quality tier: iterate|default|premium|max (default: default)
  --scale <n>        Upscale factor: 2, 4 (default: 2)
  -h, --help         Show help

Tiers:
  iterate   SeedVR2, nearly free        ${PRICING.upscale.iterate}
  default   SeedVR2, nearly free        ${PRICING.upscale.default}
  premium   Clarity, high fidelity      ${PRICING.upscale.premium}
  max       Clarity, high fidelity      ${PRICING.upscale.max}

Examples:
  bun upscale.ts photo.jpg                    # 2x default
  bun upscale.ts photo.jpg --scale 4          # 4x default
  bun upscale.ts photo.jpg -t premium         # 2x with enhancement
`);
  process.exit(0);
}

const imagePath = positionals[0];
const tier = parseTier(values.tier);
const scale = parseInt(values.scale || "2", 10);

async function main() {
  const model = UPSCALE_MODELS[tier];
  const pricing = PRICING.upscale[tier];

  console.log(`   [${tier.toUpperCase()}] ${pricing} (${scale}x)`);

  const imageUrl = await uploadToFal(imagePath);

  const input: Record<string, unknown> = {
    image_url: imageUrl,
    scale,
  };

  const result = await falQueue(model, input, OUTPUT_DIR, `upscaled_${scale}x`, "upscale", tier);

  if (!result.success) {
    process.exit(1);
  }

  console.log(`   Done: ${result.filePath}`);
}

main().catch((err) => {
  console.error(`Error: ${err.message}`);
  process.exit(1);
});
