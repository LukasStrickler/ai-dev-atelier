#!/usr/bin/env bun
import { parseArgs } from "util";
import { mkdirSync } from "fs";
import { join } from "path";
import { loadEnv, findRepoRoot } from "./lib/env";
import { falQueue, uploadToFal } from "./lib/fal-client";
import { generateCloudflare } from "./lib/cloudflare";
import {
  GEN_MODELS,
  GEN_TEXT_MODELS,
  UTIL_MODELS,
  PRICING,
  parseSize,
  parseTier,
} from "./lib/config";

loadEnv();

const repoRoot = findRepoRoot(import.meta.dir) || process.cwd();
const OUTPUT_DIR = join(repoRoot, ".ada", "data", "images");
mkdirSync(OUTPUT_DIR, { recursive: true });

const { values, positionals } = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    tier: { type: "string", short: "t", default: "default" },
    text: { type: "boolean", default: false },
    svg: { type: "boolean", default: false },
    size: { type: "string", short: "s", default: "1024x1024" },
    help: { type: "boolean", short: "h", default: false },
  },
  allowPositionals: true,
});

if (values.help || positionals.length === 0) {
  console.log(`Usage: bun gen.ts <prompt> [options]

Options:
  -t, --tier <tier>  Quality tier: iterate|default|premium|max (default: default)
  --text             Use text/logo specialist (Recraft/Ideogram)
  --svg              Convert output to SVG (adds vectorize step)
  -s, --size WxH     Output size (default: 1024x1024)
  -h, --help         Show help

Tiers (general):
  iterate   Cloudflare FREE (~96/day)   ${PRICING.gen.iterate}
  default   flux-2/turbo                ${PRICING.gen.default}
  premium   flux-2-pro                  ${PRICING.gen.premium}
  max       flux-2-max                  ${PRICING.gen.max}

Tiers (--text):
  iterate   Recraft V3                  ${PRICING.gen_text.iterate}
  default   Recraft V3                  ${PRICING.gen_text.default}
premium   Ideogram V3                 ${PRICING.gen_text.premium}
max       Ideogram V3                 ${PRICING.gen_text.max}

Examples:
  bun gen.ts "cyberpunk city"                    # default (flux-2/turbo)
  bun gen.ts "cyberpunk city" -t iterate         # FREE (Cloudflare)
  bun gen.ts "cyberpunk city" -t max             # best quality
  bun gen.ts "TechCorp logo" --text              # text specialist
  bun gen.ts "icon design" --text --svg          # vectorized output
`);
  process.exit(0);
}

const prompt = positionals.join(" ");
const tier = parseTier(values.tier);
const { width, height } = parseSize(values.size || "1024x1024");

async function main() {
  const isText = values.text;

  if (tier === "iterate" && !isText) {
    console.log(`   [ITERATE] FREE (Cloudflare ~96/day)`);
    let result = await generateCloudflare(prompt, width, height, OUTPUT_DIR);

    if (!result.success && result.code !== "CF_QUOTA_EXCEEDED" && result.code !== "CF_RATE_LIMIT") {
      console.log(`   Cloudflare failed, falling back to fal.ai flux-2/flash...`);
      result = await falQueue(
        GEN_MODELS.iterate,
        { prompt, image_size: { width, height } },
        OUTPUT_DIR,
        prompt,
        "gen",
        "iterate"
      );
    } else if (!result.success && (result.code === "CF_QUOTA_EXCEEDED" || result.code === "CF_RATE_LIMIT")) {
      process.exit(3);
    }

    if (!result.success) {
      process.exit(1);
    }

    if (values.svg && result.filePath) {
      const rasterPath = result.filePath;
      console.log(`✅ Raster: ${rasterPath}`);
      console.log(`   Vectorizing to SVG... ${PRICING.util.vectorize}`);
      const imageUrl = await uploadToFal(rasterPath);
      const svgResult = await falQueue(
        UTIL_MODELS.vectorize,
        { image_url: imageUrl },
        OUTPUT_DIR,
        prompt + "_vector",
        "svg",
        "default"
      );
      if (svgResult.success && svgResult.filePath) {
        console.log(`✅ SVG: ${svgResult.filePath}`);
        console.log(`   Done: saved both raster and SVG`);
        return;
      }
    }

    console.log(`   Done: ${result.filePath}`);
    return;
  }

  const models = isText ? GEN_TEXT_MODELS : GEN_MODELS;
  const model = models[tier];
  const pricing = isText ? PRICING.gen_text[tier] : PRICING.gen[tier];

  console.log(`   [${tier.toUpperCase()}] ${pricing}`);

  const input: Record<string, unknown> = { prompt };

  if (!isText) {
    input.image_size = { width, height };
  }

  let result = await falQueue(model, input, OUTPUT_DIR, prompt, "gen", tier);

  if (!result.success) {
    process.exit(1);
  }

  if (values.svg && result.filePath) {
    const rasterPath = result.filePath;
    console.log(`✅ Raster: ${rasterPath}`);
    console.log(`   Vectorizing to SVG... ${PRICING.util.vectorize}`);
    const imageUrl = await uploadToFal(rasterPath);
    const svgResult = await falQueue(
      UTIL_MODELS.vectorize,
      { image_url: imageUrl },
      OUTPUT_DIR,
      prompt + "_vector",
      "svg",
      "default"
    );
    if (svgResult.success && svgResult.filePath) {
      console.log(`✅ SVG: ${svgResult.filePath}`);
      console.log(`   Done: saved both raster and SVG`);
      return;
    }
  }

  console.log(`   Done: ${result.filePath}`);
}

main().catch((err) => {
  console.error(`Error: ${err.message}`);
  process.exit(1);
});
