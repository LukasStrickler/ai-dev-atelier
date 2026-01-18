---
name: image-generation
description: "Generate, edit, and upscale AI images. Use when creating visual assets for apps, websites, or documentation. FREE Cloudflare tier for iterate generation (~96/day), Fal.ai for paid tiers. Four quality tiers (iterate/default/premium/max). Supports text specialists, multi-ref editing, SVG, background removal. Triggers: generate image, create image, edit image, upscale, logo, picture of, remove background."
metadata:
  author: ai-dev-atelier
  version: "2.0"
---

# Image Generation

Generate, edit, and upscale images with standardized quality tiers.

## Quick Start

```
Need image?
├─ Text/Logo → bun scripts/gen.ts "..." --text [-t tier]
├─ Photo/Art → bun scripts/gen.ts "..." [-t tier]
├─ Edit existing → bun scripts/edit.ts <img> "..." [-t tier]
├─ Upscale → bun scripts/upscale.ts <img> [-t tier]
└─ Remove BG → bun scripts/rembg.ts <img> (FREE)

Tier selection:
├─ iterate  → FREE drafts (~96/day via Cloudflare)
├─ default  → Daily driver ($0.008/MP)
├─ premium  → Final assets ($0.03/MP)
└─ max      → Critical work, SOTA ($0.06-0.07/MP)
```

## Entry Points

| Script | Purpose |
|--------|---------|
| `bun scripts/gen.ts` | Text → Image |
| `bun scripts/edit.ts` | Image + Instruction → Image |
| `bun scripts/upscale.ts` | Image → Larger Image |
| `bun scripts/rembg.ts` | Remove background (FREE) |

## Quality Tiers

| Tier | Use Case |
|------|----------|
| `iterate` | Quick drafts, FREE for gen |
| `default` | Daily driver, balanced |
| `premium` | Final assets, quality |
| `max` | Critical work, SOTA |

## Workflow

### 1. Verify API Keys

```bash
# Check .env has required keys
# iterate tier (FREE): CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_API_TOKEN
# Other tiers: FAL_API_KEY
```

### 2. Select Tier Based on Use Case

| Scenario | Recommended Tier |
|----------|------------------|
| Quick exploration, 10+ variations | `iterate` (FREE) |
| Daily use, 3-5 variations | `default` |
| Final client deliverables | `premium` |
| Critical work, multi-reference | `max` |

### 3. Execute Script

```bash
# Generation
bun scripts/gen.ts "<prompt>" -t <tier>

# Text/Logo (uses Recraft V3 or Ideogram V2)
bun scripts/gen.ts "<prompt>" --text -t <tier>

# Editing
bun scripts/edit.ts <image> "<instruction>" -t <tier>

# Upscaling
bun scripts/upscale.ts <image> -t <tier> --scale 2

# Background removal
bun scripts/rembg.ts <image>
```

### 4. Handle Output

- **Success**: Image saved to `.ada/data/images/` with timestamp
- **Quota exceeded**: Exit code 3, no fallback to paid tier
- **API error**: Exit code 1, check error message for fix

### Exit Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Image saved |
| 1 | General error | Check error message |
| 2 | Config/auth error | Check API keys in .env |
| 3 | Resource limit | Quota exceeded, wait or use different tier |

## Generation

```bash
bun scripts/gen.ts <prompt> [-t TIER] [--text] [--svg]
```

| Tier | Provider | Cost |
|------|----------|------|
| iterate | Cloudflare | **FREE** (~96/day) |
| default | Fal.ai flux-2/turbo | $0.008/MP |
| premium | Fal.ai flux-2-pro | $0.03/MP |
| max | Fal.ai flux-2-max | $0.07/MP |

**Text/Logo** (add `--text`):
| Tier | Model | Cost |
|------|-------|------|
| iterate/default | Recraft V3 | $0.04/img |
| premium/max | Ideogram V2 | $0.08/img |

Examples:
```bash
bun scripts/gen.ts "cyberpunk city"              # default ($0.008/MP)
bun scripts/gen.ts "cyberpunk city" -t iterate   # FREE (Cloudflare)
bun scripts/gen.ts "TechCorp logo" --text        # text specialist
```

## Editing

```bash
bun scripts/edit.ts <image> <instruction> [-t TIER] [--mask] [--ref ...]
```

| Tier | Model | Cost |
|------|-------|------|
| iterate | flux-2/flash/edit | $0.005/MP |
| default | flux-2/turbo/edit | $0.008/MP |
| premium | flux-2-pro/edit | $0.03/MP |
| max | flux-2-flex/edit | $0.06/MP |

Note: 2+ `--ref` images auto-selects max tier. No free tier (CF doesn't support editing).

## Upscaling

```bash
bun scripts/upscale.ts <image> [-t TIER] [--scale 2|4]
```

| Tier | Model | Cost |
|------|-------|------|
| iterate/default | SeedVR2 | $0.001/MP |
| premium/max | Clarity | $0.03/MP |

## Background Removal

```bash
bun scripts/rembg.ts <image>                     # FREE
```

## Environment

```
CLOUDFLARE_ACCOUNT_ID=xxx   # For FREE iterate gen
CLOUDFLARE_API_TOKEN=xxx    # For FREE iterate gen
FAL_API_KEY=xxx             # For paid tiers
```

## Integration

| Skill | Use Case |
|-------|----------|
| `ui-animation` | Animate generated images for web/mobile |
| `docs-write` | Document image assets and generation parameters |
| `search` | Find prompting resources and style references |
| `code-quality` | Run after modifying skill scripts |

## References

- `references/usage-guide.md` - Comprehensive prompting guide (Flux-2, Recraft, Ideogram)
- `README.md` - Architecture diagrams and model reference
- [Fal.ai Docs](https://fal.ai/learn/devs) - Official API documentation

## Output

Images saved to `.ada/data/images/` with timestamped filenames:
```
.ada/data/images/20260118_gen_default_cyberpunk_city.jpg
```
