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
  console.log(`Usage: bun svg.ts <image>

Vectorize an existing image to SVG.

Arguments:
  <image>  Path to source image (local file or URL)

Cost: ${PRICING.util.vectorize}

Examples:
  bun svg.ts logo.png
  bun svg.ts photo.jpg
  bun svg.ts https://example.com/image.png
`);
  process.exit(0);
}

const imagePath = positionals[0];
const filename = imagePath.split("/").pop()?.split(".")[0] || "vectorized";

async function main() {
  console.log(`   [SVG] ${PRICING.util.vectorize}`);
  console.log(`   Fal.ai: ${UTIL_MODELS.vectorize}...`);

  const imageUrl = await uploadToFal(imagePath);

  const result = await falQueue(
    UTIL_MODELS.vectorize,
    { image_url: imageUrl },
    OUTPUT_DIR,
    filename,
    "svg",
    "default"
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
