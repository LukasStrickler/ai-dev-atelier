# Comprehensive Image Generation Guide

**Last Updated**: January 2026  
**Covers**: Flux-2, Recraft V3, Ideogram V3, editing, upscaling, and vectorization

---

## Overview

Modern image prompting (2025-2026) has shifted from "keyword salad" to **structured hierarchy** and **high-density prose**. Flux-2 models favor natural language and word-order priority, while text specialists (Recraft/Ideogram) require precise typography controls.

**Key Principle**: Most important elements go first, followed by supporting details.

---

## Model Rankings (January 2026)

### Text/Logo Generation

| Rank | Model | Primary Strength | Best For |
|------|-------|------------------|----------|
| **#1** | **Recraft V3** | Long text, native SVG | Professional logos, brand kits, vector assets |
| **#2** | **Ideogram V3 Turbo** | Creative layouts, typography | Posters, t-shirt designs, social media |
| **#3** | **FLUX.2 Max** | Photorealistic text in scenes | Ad creatives, text in 3D environments |
| **#4** | Imagen 4 Ultra | Semantic coherence | Short branding phrases |

### General Image Generation

| Tier | Model | Speed | Quality | Cost |
|------|-------|-------|---------|------|
| iterate | Flux-2 Klein (Cloudflare) | Sub-second | Good drafts | **FREE** (~96/day) |
| default | Flux-2 Turbo | Very fast | High adherence | $0.008/MP |
| premium | Flux-2 Pro | Medium | Excellent | $0.03/MP |
| max | Flux-2 Max | Slow | SOTA | $0.07/MP |

---

## Flux-2 Prompting (Generation)

### Four-Pillar Structure (Recommended)

Flux-2 responds best to prompts structured as:

```
1. Subject (most important)
2. Action/State
3. Style + Lighting
4. Technical/Context
```

**Example**:
> "A titanium luxury watch with #0047AB accent. Submerged in clear water with rising air bubbles. Soft morning sunlight filtering through canopy, creating dappled bokeh. Macro photography, 100mm lens, f/2.8."

### Lighting (Critical for Quality)

Lighting is the **single most important element** for Flux-2 quality. Always describe:

| Aspect | Examples |
|--------|----------|
| **Source** | Natural sunlight, neon, candlelight, overcast sky |
| **Quality** | Diffused, direct, harsh, cinematic, soft |
| **Direction** | Top-down, side-lit, backlit, rim-lit |
| **Temperature** | Warm, cool, neutral, golden hour |

**Good**: "Soft, diffused morning light filtering through high clerestory windows, casting long, warm shadows across polished concrete floor."

**Bad**: "Cinematic lighting" (too vague)

### Color Precision

Flux-2 supports **direct HEX codes** for brand accuracy:

```
"A sports car in color #FF5733 with #2ecc71 racing stripes"
```

When not using HEX, use **precise color descriptions**:
- ✅ "Vibrant electric blue with metallic sheen"
- ❌ "Blue car"

### No Negative Prompts

Flux-2 **does not support negative prompts**. Describe what SHOULD be:

| Instead of... | Write... |
|---------------|----------|
| "No blur, sharp focus" | "Sharp focus throughout, high contrast" |
| "No people, empty street" | "An empty street at dusk" |
| "Without glasses" | "Clear eyes, no accessories on face" |

### JSON-Structured Prompting (Pro/Max Only)

For complex multi-subject scenes:

```json
{
  "scene": "A futuristic Tokyo storefront",
  "subjects": [
    {
      "description": "Cyberpunk robot",
      "color": "#FFD700",
      "action": "eating noodles",
      "position": "center"
    }
  ],
  "lighting": "Neon cyan and magenta rim light",
  "camera": { "lens": "35mm", "angle": "low-angle" }
}
```

### Common Mistakes

| Mistake | Why It Fails | Fix |
|---------|--------------|-----|
| Keyword stuffing | "4k, masterpiece, trending" is noise | Use descriptive sentences |
| Vague subjects | "a man" interpreted randomly | "middle-aged man with salt-and-pepper hair" |
| Short prompts | Under 20 words underperforms | Aim for 40-80 words |
| Negative phrasing | Often adds what you want removed | Describe target state only |

---

## Text & Logo Generation (--text Flag)

### Model Selection Guide

| Need | Model | Flag | Notes |
|------|-------|------|-------|
| Professional logos, SVG output | Recraft V3 | `--text` | Native vector, 1500+ fonts |
| Creative posters, complex layouts | Ideogram V3 Turbo | `--text -t premium` | Layout engine |
| Text IN photorealistic scenes | Flux-2 Max | (no flag, describe text) | For signs, billboards in photos |
| Minimalist icons | Recraft V3 | `--text --svg` | Clean vectorization |

### Recraft V3 Deep Dive

**Why #1 for Logos**:
- Native **SVG vector output** (only frontier model with this)
- **1500+ integrated fonts** with granular control
- **Brand Style Consistency** - upload existing logo to generate matching assets
- **Agentic Mode** (Dec 2025) - iterate through conversation

#### The Blueprint Format

```
A <image style> of <main content>. <detailed description>. <background description>. <style description>.
```

**Example**:
> "A vector logo of a sustainable energy company named 'VERIDIAN'. The word 'VERIDIAN' is in a bold, clean geometric sans-serif font. Above the text, a stylized green leaf integrated into a circular power icon. Pure white background, flat vector style, minimalist aesthetic."

#### Logo Design Patterns

| Style | Prompt Pattern | When to Use |
|-------|----------------|-------------|
| **Minimalist** | `"BRAND" minimalist vector logo, clean lines, simple geometry, flat design` | Tech, modern brands |
| **Vintage/Badge** | `"EST. 1920" vintage badge logo, circular emblem, ribbon banner, ornate border` | Craft, artisan brands |
| **Negative Space** | `"PEAK" logo where the letter A forms a mountain, negative space design` | Clever, memorable marks |
| **3D/Modern** | `"TECHCORP" bold 3D chrome letters, gradient fill, dark background` | Gaming, entertainment |
| **Wordmark** | `"ACME" custom logotype, unique letterforms, balanced kerning` | Strong brand names |

#### Font Specification

Use typography terms for control:

| Term | Result |
|------|--------|
| `modern sans-serif` | Clean, geometric (like Helvetica) |
| `elegant serif` | Traditional, refined (like Times) |
| `bold condensed` | Impactful, space-efficient |
| `blackletter` | Gothic, medieval feel |
| `script/cursive` | Handwritten, elegant |
| `monospace` | Technical, code-like |
| `slab serif` | Strong, sturdy (like Rockwell) |

#### Artistic Level Parameter

Control creativity vs. precision:

| Level | Output | Use For |
|-------|--------|---------|
| Low (0-2) | Standard, direct compositions | Clean corporate logos |
| Medium (4-6) | Balanced creativity | Most use cases |
| High (8-10) | Unconventional, experimental | Creative exploration |

### Ideogram V3 Turbo Deep Dive

**Upgraded from V2** (Q4 2025) with "Deep Typography" and layout awareness.

#### Key Techniques

1. **Quotation Marks Required**:
   > `A vibrant neon sign that says "NEON NIGHTS" in a retro 80s cursive font.`

2. **Text-First Positioning**: Mention text in first 10 words
   > `"SALE" headline at top, "50% OFF" subtext at bottom, vibrant red background`

3. **Style Presets**:
   - `DESIGN`: Logos, icons, flat graphics
   - `REALISTIC`: Signs, packaging, text in wild

4. **Color Palette Control**:
   ```
   color_palette: { members: [{ color_hex: "#2ecc71", color_weight: 1.0 }] }
   ```

### Text Rendering in Flux-2

**FLUX.2 Max** (Nov 2025) significantly improved text coherence over FLUX.1, but still ranks #3 behind Recraft/Ideogram for pure typography.

**When Flux-2 Works for Text**:
- Text ON objects in photorealistic scenes (signs, billboards, packaging)
- Short phrases (1-3 words) integrated into environments
- When you need photorealism more than text precision

**When to Use Specialists Instead**:
- Clean logos or brand marks → Recraft V3
- Posters with complex typography → Ideogram V3
- Any text longer than 3 words → Specialists
- SVG/vector output needed → Recraft V3 + `--svg`

### DO/DON'T for Text Generation

| DO | DON'T |
|----|-------|
| Put text in "Double Quotes" at prompt START | Bury text in middle of prompt |
| Specify font style explicitly | Say just "nice font" |
| Use exact counts: "Three cats" | Use plurals: "cats" (random count) |
| Clarify ambiguous words: "wooden baseball bat" | Just say "bat" |
| Describe what you WANT | Use negatives: "no cake" (adds cake) |

---

## Image Editing

```bash
bun scripts/edit.ts <image> <instruction> [-t TIER] [--mask <mask.png>] [--ref <img>...]
```

### Writing Edit Instructions

**Key Principle**: Describe the TARGET STATE, not the change.

| Bad Instruction | Good Instruction |
|-----------------|------------------|
| "change car to blue" | "A sleek blue metallic sports car, reflections of neon lights on wet asphalt" |
| "add a hat" | "person wearing a vintage red fedora, matching the scene lighting" |
| "remove background" | Use `rembg.ts` instead (FREE and better) |
| "make it better" | Specify exactly what to improve |

### Mask Best Practices

| Task | Mask Strategy |
|------|---------------|
| **Object removal** | Mask 10-20px LARGER than object |
| **Object addition** | Mask exact shape or slightly smaller |
| **Outpainting** | Overlap 10-20px INTO original image |
| **Sky replacement** | Include horizon line in mask |

**Feathering**: Apply 12-16px Gaussian blur to masks. Sharp masks = visible seams.

### Multi-Reference Editing

Using 2+ `--ref` images auto-selects `max` tier (flux-2-flex).

```bash
# Style transfer
bun scripts/edit.ts base.jpg "in the style of the reference" --ref style.jpg

# Multi-reference blending
bun scripts/edit.ts scene.jpg "forest sofa scene" --ref forest.jpg --ref sofa.jpg
```

**Blending Tip**: Describe the RELATIONSHIP between references:
> "A velvet sofa placed in the center of a misty pine forest"

### Common Edit Failures & Fixes

| Issue | Cause | Solution |
|-------|-------|----------|
| Identity drift (face changes) | Model hallucinating | Use ControlNet/structure preservation |
| Seams visible | Sharp mask edges | Add 12-16px feather to mask |
| Wrong area edited | Mask too large | Make mask more precise |
| Style doesn't transfer | Weak reference signal | Use higher tier (max) |

---

## Upscaling

```bash
bun scripts/upscale.ts <image> [-t TIER] [--scale 2|4]
```

### 2x vs 4x Decision Matrix

| Source Quality | Characteristics | Recommendation |
|----------------|-----------------|----------------|
| **High** | RAW, clean PNG, high-bitrate | 4x safe |
| **Medium** | Standard JPEG, slight noise | 2x preferred |
| **Low** | Heavy compression, blur | 2x maximum |

**Rule of Thumb**: If image looks "crunchy" at 100% zoom, don't exceed 2x.

### Use Case Guidelines

| Output | Scale | Notes |
|--------|-------|-------|
| Web/UI | 2x | Improves perceived sharpness, manageable file size |
| Print (300 DPI) | 4x | Calculate: target_px = target_inches × 300 |
| Icons/Logos | 2x | Use `svg.ts` instead for infinite scaling |
| Social media | 2x | Balances quality and upload limits |

### Common Artifacts & Prevention

| Artifact | Cause | Prevention |
|----------|-------|------------|
| Haloing (white edges) | Aggressive sharpening | Use iterate/default tier |
| Plasticky skin | Over-smoothing | Use 2x, avoid premium on faces |
| Grid patterns | Tile processing | Use higher tier models |
| Oil painting effect | Low-quality source | Denoise before upscaling |

### Pre-Upscaling Checklist

1. **Denoise first** - Noise gets magnified
2. **Remove JPEG artifacts** - Run artifact removal at 1x first
3. **Fix white balance** - AI performs better with balanced contrast
4. **Light sharpening** - Subtle unsharp mask (0.5-1.0 radius)

---

## SVG Vectorization

```bash
bun scripts/svg.ts <image>  # $0.01/img
```

### When to Vectorize

| Use Case | Vectorize? |
|----------|------------|
| Logo for print/signage | ✅ Yes |
| Icon for multiple sizes | ✅ Yes |
| Illustration for web | ✅ Yes |
| Photo | ❌ No (rasterize artifacts) |
| Complex gradients | ⚠️ Maybe (test first) |

### Best Source Images for SVG

- Clean edges, solid colors
- High contrast
- Simple shapes
- Generated with `--text` flag (already optimized)

---

## Tier Selection Guide

### Quick Decision Matrix

| Scenario | Tier | Why |
|----------|------|-----|
| Exploring 10+ variations | `iterate` | FREE, fast iteration |
| Daily work, 3-5 variations | `default` | Best cost/quality |
| Client deliverables | `premium` | Higher fidelity |
| Critical assets, multi-ref | `max` | SOTA, advanced features |
| Text/logos (standard) | `default` | Recraft V3 already excellent |
| Text/logos (critical) | `premium` | Ideogram V3 for perfect typography |

### Cost Optimization Workflow

```
❌ EXPENSIVE (avoid):
  Generate at max → iterate on max → deliver
  Cost: $0.07 × 10 attempts = $0.70

✅ COST-EFFECTIVE (recommended):
  Generate at iterate (FREE) → find best concept (10 tries)
  → Regenerate winner at default → deliver
  Cost: $0.00 + $0.008 = $0.008
```

### Exit Codes

| Code | Meaning | Retryable | Action |
|------|---------|-----------|--------|
| 0 | Success | N/A | Image saved |
| 1 | General error | Maybe | Check error message |
| 2 | Config error | No | Fix API keys in `.env` |
| 3 | Resource limit | Yes (after wait) | Quota exceeded |

**CRITICAL**: Exit code 3 does NOT fall back to paid tier. This prevents accidental charges.

---

## Error Codes Reference

### Cloudflare Errors

| Code | Meaning | Fix |
|------|---------|-----|
| `CF_AUTH_MISSING` | API keys not configured | Add `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` to `.env` |
| `CF_QUOTA_EXCEEDED` | Daily limit (~96/day) | Wait until midnight UTC or use `default` tier |
| `CF_RATE_LIMIT` | Too many requests | Wait 60s and retry |
| `CF_ERROR` | General API error | Check error message |

### Fal.ai Errors

| Code | Meaning | Fix |
|------|---------|-----|
| `FAL_AUTH_INVALID` | Invalid API key | Check `FAL_API_KEY` in `.env` |
| `FAL_CREDITS_EXHAUSTED` | No credits | Add credits at [fal.ai/dashboard](https://fal.ai/dashboard) |
| `FAL_RATE_LIMIT` | Rate limit hit | Wait 60s and retry |
| `FAL_JOB_TIMEOUT` | Job took too long | Retry or use faster tier |
| `FAL_NO_IMAGE` | No image in response | Retry with different prompt |
| `FAL_ERROR` | General API error | Check error message |

---

## Aspect Ratios & Composition

### Common Ratios

| Ratio | Dimensions | Best For |
|-------|------------|----------|
| **1:1** | 1024×1024 | Portraits, logos, icons |
| **16:9** | 1920×1080 | Landscapes, presentations, hero images |
| **9:16** | 1080×1920 | Stories, mobile, phone wallpapers |
| **4:5** | 816×1024 | Documents, Instagram posts |
| **3:2** | 1536×1024 | Photography, prints |

### Composition Keywords

| Category | Keywords |
|----------|----------|
| **Viewpoint** | Bird's eye, low angle, worm's eye, over-the-shoulder, POV |
| **Framing** | Extreme close-up, medium shot, full body, wide shot |
| **Balance** | Symmetrical, rule of thirds, golden ratio, centered |
| **Depth** | Shallow DOF, bokeh, deep focus, tilt-shift |

---

## Prompt Libraries & Resources

### Curated Databases

| Resource | Best For |
|----------|----------|
| [All-Image-Prompts](https://github.com/junxiaopang/all-image-prompts) | Multi-model search (Flux, MJ, Grok) |
| [Civitai](https://civitai.com/models) | Full generation metadata, Flux styles |
| [Lexica.art](https://lexica.art) | Visual search, cinematic prompts |
| [PromptHero](https://prompthero.com) | DALL-E 3, Midjourney prompts |

### Specialized Collections

| Resource | Focus |
|----------|-------|
| [FLUX.1-pro Cheatsheet](https://github.com/AWTom/FLUX.1-pro-cheatsheet) | 904 artist styles |
| [Kiko Flux 2 Prompt Builder](https://github.com/ComfyAssets/kiko-flux2-prompt-builder) | JSON builder with presets |
| [Logo Design Prompts](https://github.com/friuns2/BlackFriday-GPTs-Prompts) | Minimalist, vector, 3D templates |

### Official Documentation

| Guide | Date |
|-------|------|
| [Flux.2 Guide](https://fal.ai/learn/devs/flux-2-prompt-guide) | Dec 2025 |
| [Flux.2 Max Guide](https://fal.ai/learn/devs/flux-2-max-prompt-guide) | Dec 19, 2025 |
| [Flux.2 Turbo Guide](https://fal.ai/learn/devs/flux-2-turbo-prompt-guide) | Jan 7, 2026 |
| [Recraft V3 Docs](https://www.recraft.ai/docs/recraft-models/recraft-V3) | Jan 2026 |
| [Ideogram V3 Docs](https://docs.ideogram.ai/using-ideogram/prompting-guide) | Late 2025 |

---

## Quick Reference Commands

### Generation

```bash
# FREE iteration (Cloudflare)
bun scripts/gen.ts "a sunset over mountains" -t iterate

# Standard quality (Fal.ai)
bun scripts/gen.ts "cyberpunk city at night" -t default

# With precise color
bun scripts/gen.ts "sports car #FF5733" -t premium

# Text/logo (Recraft V3)
bun scripts/gen.ts '"ACME" bold modern logo' --text

# Text/logo with vector output
bun scripts/gen.ts '"ACME" minimalist logo' --text --svg

# Premium text (Ideogram V3)
bun scripts/gen.ts '"QUANTUM" futuristic poster' --text -t premium
```

### Editing

```bash
# Simple instruction
bun scripts/edit.ts photo.jpg "change sky to purple sunset"

# With mask (inpainting)
bun scripts/edit.ts photo.jpg "add sunglasses" --mask mask.png

# Style transfer
bun scripts/edit.ts photo.jpg "apply this style" --ref style.jpg

# Multi-reference (auto max tier)
bun scripts/edit.ts base.jpg "blend these" --ref ref1.jpg --ref ref2.jpg
```

### Utilities

```bash
# Upscale 2x
bun scripts/upscale.ts image.jpg --scale 2

# Upscale 4x with quality
bun scripts/upscale.ts image.jpg --scale 4 -t premium

# Remove background (FREE)
bun scripts/rembg.ts photo.jpg

# Vectorize to SVG
bun scripts/svg.ts logo.png
```

---

## Testing

### Verify Output Directory

```bash
# Test from repo root
bun scripts/gen.ts "test" -t iterate
# Expected: .ada/data/images/...

# Test from subdirectory (MUST work)
cd content/skills
bun ../../content/skills/image-generation/scripts/gen.ts "test" -t iterate
# Expected: Still saves to repo root .ada/data/images/
```

### Verify Error Handling

```bash
# Missing Cloudflare keys
unset CLOUDFLARE_ACCOUNT_ID
bun scripts/gen.ts "test" -t iterate
# Expected: Clear error, exit code 2

# Missing Fal.ai key  
unset FAL_API_KEY
bun scripts/gen.ts "test" -t default
# Expected: Clear error, exit code 2
```

### Full Feature Test

```bash
# Generation tiers
bun scripts/gen.ts "sunset mountains" -t iterate    # FREE
bun scripts/gen.ts "cyberpunk city" -t default      # Paid

# Text/logo
bun scripts/gen.ts '"LOGO" modern design' --text
bun scripts/gen.ts '"LOGO" modern design' --text --svg

# Edit
bun scripts/edit.ts photo.jpg "make sky purple"

# Upscale
bun scripts/upscale.ts image.jpg --scale 2

# Background removal
bun scripts/rembg.ts photo.jpg

# Vectorize
bun scripts/svg.ts logo.png
```
