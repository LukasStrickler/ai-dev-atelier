#!/usr/bin/env bun
import { parseArgs } from "util";
import { mkdirSync } from "fs";
import { join } from "path";
import { loadEnv, findRepoRoot } from "./lib/env";
import { falQueue, uploadToFal } from "./lib/fal-client";
import { UTIL_MODELS, PRICING } from "./lib/config";

loadEnv();

const repoRoot = findRepoRoot(import.meta.dir) || process.cwd();
const OUTPUT_DIR = join(repoRoot, ".ada", "data", "images");
mkdirSync(OUTPUT_DIR, { recursive: true });

const { values, positionals } = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    help: { type: "boolean", short: "h", default: false },
  },
  allowPositionals: true,
});

if (values.help || positionals.length === 0) {
  console.log(`Usage: bun rembg.ts <image>

Remove background from image (FREE).

Arguments:
  <image>  Path to source image (local file or URL)

Cost: ${PRICING.util.rembg}

Examples:
  bun rembg.ts photo.jpg
  bun rembg.ts https://example.com/photo.png
`);
  process.exit(0);
}

const imagePath = positionals[0];

async function main() {
  console.log(`   [REMBG] ${PRICING.util.rembg}`);

  const imageUrl = await uploadToFal(imagePath);

  const result = await falQueue(
    UTIL_MODELS.rembg,
    { image_url: imageUrl },
    OUTPUT_DIR,
    "nobg",
    "rembg",
    "free"
  );

  if (!result.success) {
    process.exit(1);
  }

  console.log(`   Done: ${result.filePath}`);
}

main().catch((err) => {
  console.error(`Error: ${err.message}`);
  process.exit(1);
});
