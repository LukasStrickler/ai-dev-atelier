# Image Generation Skill

Fal.ai + Cloudflare-powered image generation, editing, and upscaling with standardized quality tiers.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           IMAGE GENERATION SKILL                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐      │
│  │   gen.ts    │   │   edit.ts   │   │ upscale.ts  │   │  rembg.ts   │      │
│  │ Text→Image  │   │ Image→Image │   │  Upscale    │   │  Remove BG  │      │
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘   └──────┬──────┘      │
│         │                 │                 │                 │             │
│         ▼                 ▼                 ▼                 ▼             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         TIER SYSTEM                                 │    │
│  │  iterate  │  default  │  premium  │  max                            │    │
│  │  FREE/$$  │  Balanced │  Quality  │  SOTA                           │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│         │                 │                 │                 │             │
│         ▼                 ▼                 ▼                 ▼             │
│  ┌──────────────┐  ┌─────────────────────────────────────────────────┐      │
│  │  CLOUDFLARE  │  │                   FAL.AI                        │      │
│  │  (gen only)  │  │  (gen/edit/upscale/utils)                       │      │
│  └──────────────┘  └─────────────────────────────────────────────────┘      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Quality Tiers

All operations use the same 4-tier system:

| Tier | Use Case | Cost |
|------|----------|------|
| `iterate` | Quick drafts, exploration, many variations | FREE or Cheapest |
| `default` | Daily driver, balanced cost/quality | Balanced |
| `premium` | Final assets, high quality output | Higher |
| `max` | Critical deliverables, SOTA quality | Highest |

## Entry Points

| Script | Purpose | Example |
|--------|---------|---------|
| `gen.ts` | Text → Image | `bun gen.ts "a sunset"` |
| `edit.ts` | Image + Instruction → Image | `bun edit.ts photo.jpg "make it blue"` |
| `upscale.ts` | Image → Larger Image | `bun upscale.ts photo.jpg` |
| `svg.ts` | Image → SVG | `bun svg.ts logo.png` |
| `rembg.ts` | Image → Image (no background) | `bun rembg.ts photo.jpg` |

## Routing Diagrams

### Generation (`gen.ts`)

```
bun gen.ts <prompt> [-t TIER] [--text] [--svg]

         ┌──────────────────────────────────────────────────────────────┐
         │                      --text flag?                            │
         └──────────────────────────┬───────────────────────────────────┘
                                    │
              ┌─────────────────────┴─────────────────────┐
              │ YES                                   NO  │
              ▼                                           ▼
    ┌─────────────────────┐                   ┌──────────────────────┐
    │   TEXT SPECIALIST   │                   │  GENERAL GENERATION  │
    │   (logos, text)     │                   │  (photos, art)       │
    ├─────────────────────┤                   ├──────────────────────┤
    │ iterate: Recraft V3 │                   │ iterate: CLOUDFLARE  │
    │          $0.04/img  │                   │          FREE        │
    │ default: Recraft V3 │                   │ default: flux-2/turbo│
    │          $0.04/img  │                   │          $0.008/MP   │
    │ premium: Ideogram V2│                   │ premium: flux-2-pro  │
    │          $0.08/img  │                   │          $0.03/MP    │
    │ max:     Ideogram V2│                   │ max:     flux-2-max  │
    │          $0.08/img  │                   │          $0.07/MP    │
    └─────────────────────┘                   └──────────────────────┘

         iterate (general) ──► Cloudflare flux-2-klein (~96 imgs/day FREE)
                               Falls back to fal.ai flux-2/flash if CF fails

         --svg? ──► + Vectorize step ($0.01/img)
```

### Editing (`edit.ts`)

```
bun edit.ts <image> <instruction> [-t TIER] [--mask] [--ref ...]

         ┌──────────────────────────────────────────────────────────────┐
         │                    2+ --ref images?                          │
         └──────────────────────────┬───────────────────────────────────┘
                                    │
              ┌─────────────────────┴─────────────────────┐
              │ YES (auto-max)                        NO  │
              ▼                                           ▼
    ┌─────────────────────┐                   ┌─────────────────────┐
    │  MULTI-REFERENCE    │                   │   STANDARD EDIT     │
    │  (style transfer)   │                   │   (instructions)    │
    ├─────────────────────┤                   ├─────────────────────┤
    │ max: flux-2-flex    │                   │ iterate: flash/edit │
    │      $0.06/MP       │                   │          $0.005/MP  │
    └─────────────────────┘                   │ default: turbo/edit │
                                              │          $0.008/MP  │
                                              │ premium: pro/edit   │
                                              │          $0.03/MP   │
                                              │ max:     flex/edit  │
                                              │          $0.06/MP   │
                                              └─────────────────────┘

         --mask ──► Inpainting mode (white pixels = edit area)

         Note: No free tier for editing (Cloudflare only supports text-to-image)
```

### Upscaling (`upscale.ts`)

```
bun upscale.ts <image> [-t TIER] [--scale 2|4]

    ┌─────────────────────────────────────────────────────────────┐
    │                      UPSCALE MODELS                         │
    ├─────────────────────────────────────────────────────────────┤
    │ iterate: SeedVR2              $0.001/MP  (nearly free)      │
    │ default: SeedVR2              $0.001/MP  (nearly free)      │
    │ premium: Clarity Upscaler     $0.03/MP   (enhanced)         │
    │ max:     Clarity Upscaler     $0.03/MP   (enhanced)         │
    └─────────────────────────────────────────────────────────────┘

    Note: iterate/default = same model (no cheaper upscaler exists)
          premium/max = same model (Clarity is the best available)
```

### Utilities

```
bun rembg.ts <image>

    ┌─────────────────────────────────────────────────────────────┐
    │ imageutils/rembg                                    FREE    │
    └─────────────────────────────────────────────────────────────┘
```

## Model Reference

### Generation Models

| Tier | Provider | Model ID | Cost |
|------|----------|----------|------|
| iterate | Cloudflare | `flux-2-klein-4b` | **FREE** (~96/day) |
| default | Fal.ai | `fal-ai/flux-2/turbo` | $0.008/MP |
| premium | Fal.ai | `fal-ai/flux-2-pro` | $0.03/MP |
| max | Fal.ai | `fal-ai/flux-2-max` | $0.07/MP |

### Text/Logo Models (--text flag)

| Tier | Model ID | Cost |
|------|----------|------|
| iterate | `fal-ai/recraft/v3/text-to-image` | $0.04/img |
| default | `fal-ai/recraft/v3/text-to-image` | $0.04/img |
| premium | `fal-ai/ideogram/v2` | $0.08/img |
| max | `fal-ai/ideogram/v2` | $0.08/img |

### Edit Models

| Tier | Model ID | Cost |
|------|----------|------|
| iterate | `fal-ai/flux-2/flash/edit` | $0.005/MP |
| default | `fal-ai/flux-2/turbo/edit` | $0.008/MP |
| premium | `fal-ai/flux-2-pro/edit` | $0.03/MP |
| max | `fal-ai/flux-2-flex/edit` | $0.06/MP |

### Upscale Models

| Tier | Model ID | Cost |
|------|----------|------|
| iterate | `fal-ai/seedvr/upscale/image` | $0.001/MP |
| default | `fal-ai/seedvr/upscale/image` | $0.001/MP |
| premium | `fal-ai/clarity-upscaler` | $0.03/MP |
| max | `fal-ai/clarity-upscaler` | $0.03/MP |

### Utility Models

| Tool | Model ID | Cost |
|------|----------|------|
| rembg | `fal-ai/imageutils/rembg` | FREE |
| vectorize | `fal-ai/recraft/vectorize` | $0.01/img |

## Provider Notes

**Cloudflare Workers AI** (iterate tier for generation):
- FREE tier: ~96 images/day at 1024x1024
- Only supports text-to-image (no editing/upscaling)
- Falls back to Fal.ai if rate limited

**Fal.ai** (all other operations):
- Unified API for gen/edit/upscale
- Consistent pricing (megapixel-based)
- Queue-based async processing

## CLI Reference

### gen.ts
```bash
bun gen.ts <prompt> [options]

Options:
  -t, --tier <tier>  iterate|default|premium|max (default: default)
  --text             Use text/logo specialist
  --svg              Vectorize output to SVG
  -s, --size WxH     Output size (default: 1024x1024)
```

### edit.ts
```bash
bun edit.ts <image> <instruction> [options]

Options:
  -t, --tier <tier>  iterate|default|premium|max (default: default)
  -m, --mask <path>  Mask for inpainting (white = edit)
  --ref <path>       Reference image(s), repeatable
```

### upscale.ts
```bash
bun upscale.ts <image> [options]

Options:
  -t, --tier <tier>  iterate|default|premium|max (default: default)
  --scale <n>        2 or 4 (default: 2)
```

### rembg.ts
```bash
bun rembg.ts <image>
```

## Environment

```bash
# Required for iterate tier (FREE generation)
CLOUDFLARE_ACCOUNT_ID=your_account_id
CLOUDFLARE_API_TOKEN=your_api_token

# Required for all other tiers
FAL_API_KEY=your_fal_key
```

Auto-loaded from repo root `.env` file.

## Output

Images saved to `.ada/data/images/` with timestamped filenames:
```
.ada/data/images/20260117_cyberpunk_city.png
```

## Structure

```
scripts/
├── gen.ts           # Text-to-image (CF iterate + Fal.ai tiers)
├── edit.ts          # Image editing (Fal.ai only)
├── upscale.ts       # Upscaling (Fal.ai only)
├── svg.ts           # Vectorization to SVG (Fal.ai)
├── rembg.ts         # Background removal (Fal.ai FREE)
├── types.ts         # TypeScript types
└── lib/
    ├── config.ts    # Models, tiers, pricing
    ├── cloudflare.ts # Cloudflare Workers AI client
    ├── fal-client.ts # Fal.ai queue API
    ├── env.ts       # .env loader
    └── utils.ts     # File utilities
```

## Swapping Models

To update models when new ones release, edit `lib/config.ts`:

```typescript
export const GEN_MODELS: Record<Tier, string> = {
  iterate: "fal-ai/flux-2/flash",      // Fallback when CF fails
  default: "fal-ai/flux-2/turbo",
  premium: "fal-ai/flux-2-pro",
  max: "fal-ai/flux-2-max",
};
```

For Cloudflare model changes, edit `lib/cloudflare.ts`.
