# Prompting Guide for Image Generation

**Last Updated**: January 2026  
**Covers**: Flux-2, Recraft V3, Ideogram V2, editing, and upscaling

---

## Overview

Modern image prompting (2025-2026) has shifted from "keyword salad" to **structured hierarchy** and **high-density prose**. Flux-2 models favor natural language and word-order priority, while text specialists (Recraft/Ideogram) require precise typography controls.

**Key Principle**: Most important elements go first, followed by supporting details.

---

## Flux-2 Prompting (Generation)

### Model Variants

| Model | Speed | Quality | Best Use |
|--------|--------|----------|-----------|
| **Flux-2 Klein** (Cloudflare) | Sub-second | Good drafts | FREE iteration, quick exploration |
| **Flux-2 Turbo** | Very fast | High adherence | Daily use, rapid iteration |
| **Flux-2 Pro** | Medium | Excellent | Final assets, complex scenes |
| **Flux-2 Max** | Slow | SOTA | Critical deliverables, multi-reference |

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

### Key Techniques

#### Lighting (Critical for Klein)
Lighting is the **single most important element** for Flux-2 Klein quality. Always describe:

- **Source**: Natural (sunlight, overcast, neon, candlelight)
- **Quality**: Diffused, direct, harsh, cinematic, soft
- **Direction**: Top-down, side-lit, backlit, rim-lit
- **Temperature**: Warm, cool, neutral, golden hour

**Good Example**:
> "Soft, diffused morning light filtering through high clerestory windows, casting long, warm shadows across polished concrete floor."

**Bad Example**:
> "Cinematic lighting" (too vague, model guesses)

#### Color Precision
Flux-2 supports **direct HEX codes** for brand accuracy:

> "A sports car in color #FF5733 with #2ecc71 racing stripes"

When not using HEX, use **precise color descriptions**:
- "Vibrant electric blue" ✅
- "Blue car" ❌ (model may choose wrong shade)

#### No Negative Prompts
Flux-2 **does not support negative prompts**. Instead of what to avoid, describe what should be:

- ❌ "No blur, sharp focus"
- ✅ "Sharp focus throughout, high contrast"
- ❌ "No people, empty street"
- ✅ "An empty street at dusk"

#### JSON-Structured Prompting (Pro/Max Only)
For complex multi-subject scenes, use JSON for precise control:

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

1. **Keyword Stuffing** (Klein): Using "4k, high resolution, masterpiece" degrades performance
   - **Fix**: Use descriptive sentences instead
   
2. **Prompt Upsampling** (Klein): Klein doesn't support `prompt_upsampling` parameter
   - **Fix**: Be descriptive yourself
   
3. **Small Reference Images**: Keep reference images under 512x512 for optimal processing

### Example Prompts by Use Case

#### Photorealistic (Pro/Max)
> "Shot on Hasselblad X2D, 80mm lens, f/2.8. A macro shot of a single drop of water resting on a vibrant green leaf, #00FF00 green reflecting in the droplet. Dappled sunlight filters through forest canopy, creating a bokeh background."

#### Narrative (Klein)
> "A weathered fisherman in his late sixties stands at the bow of a small wooden boat. He is wearing a salt-stained wool sweater, his hands gripping a frayed rope. Golden hour sunlight filters through morning mist, creating a sense of quiet determination."

#### Product Photography (Turbo/Pro)
> "Editorial product shot of a premium wireless earbud. Glossy matte black finish, subtle #333333 accents. Clean white infinity-curve background with soft studio lighting. 100mm macro lens, f/4.0, sharp focus on product details."

---

## Text & Logo Prompting (--text Flag)

### Choosing: Recraft V3 vs Ideogram V2

| Feature | Recraft V3 | Ideogram V2 |
|----------|---------------|--------------|
| **Primary Strength** | Design, vectors, long text | Photorealism, high impact |
| **Text Limit** | High (paragraphs, posters) | Medium (words, phrases) |
| **Spatial Control** | Excellent (positioning tools) | Good (prompt ordering) |
| **Output Formats** | Native SVG/Vector + Raster | Raster (high-quality JPG/PNG) |
| **Typography** | 1500+ integrated fonts | Intelligent, less granular |
| **When to Use** | Professional branding, packaging, icons | Social media ads, posters, realistic mockups |

### Recraft V3 Best Practices

#### Designer's Blueprint Format
> `A <image style> of <main content>. <detailed description>. <background description>. <style description>.`

**Example**:
> "A vector logo of a sustainable energy company named 'VERIDIAN'. The word 'VERIDIAN' is in a bold, clean geometric sans-serif font. Above the text, a stylized green leaf integrated into a circular power icon. Pure white background, flat vector style, minimalist aesthetic."

#### Key Features

- **Positioning Control**: Specify exact text placement
  > "The word 'COFFEE' centered in large bold letters, with tagline 'Always Fresh' in smaller script below it"

- **Artistic Level**: Control standard vs creative output
  - **Low (0-2)**: Standard, direct compositions (clean logos)
  - **High (8-10)**: Unconventional angles, creative perspectives

- **Font Control**: Specify font families or styles
  > "Minimalist sans-serif", "Elegant serif with high contrast", "Bold condensed"

- **Brand Style**: Upload 3-5 images to establish consistent brand style

### Ideogram V2 Best Practices

#### Quotation Marks
**Always enclose exact text in quotes**:
> `A vibrant neon sign that says "NEON NIGHTS" in a retro 80s cursive font.`

#### Primary Positioning
Mention text **early** in prompt:
> "Headline says 'SALE' at top, subtext says '50% OFF' at bottom"

#### Style Presets
- `DESIGN`: Best for logos, icons, flat graphics
- `REALISTIC`: Best for "text in wild" (signs, packaging)

#### Color Palettes
Define colors precisely:
> `color_palette: { members: [{ color_hex: "#2ecc71", color_weight: 1.0 }] }`

### Common Tips (Both Models)

1. **Avoid Negative Prompts**: Describe what should exist, not what to avoid
   - ❌ "No flowers"
   - ✅ "Minimalist and clinical"

2. **Use Synonyms**: Clarify ambiguous nouns
   - "A flying mammal bat" (clear) vs "A bat" (could be baseball bat)

3. **Precision over Length**: Modern models prioritize descriptive precision

4. **Lighting and Material**: Define the "feel"
   - "Flat vector", "Glossy 3D", "Embossed on paper"

---

## Editing Prompting

### Transformation-First Phrasing
For image-to-image editing, **focus only on the change**:

❌ **Weak**: "A woman in a red dress standing in a park."
✅ **Strong**: "Change dress color to red."

### Context Preservation
For models like Flux 2 Pro Edit, use instructions to maintain environment:
> "Keep the background unchanged, only modify the subject's clothing."

### Inpainting (--mask flag)
White pixels in mask = edit area. Describe only the change, not the whole scene:
> "Make the sky purple" (with mask covering sky only)

### Multi-Reference Composition
When using 2+ `--ref` images, describe how to combine them:
> "Take the subject from image 0 and place them in environment of image 1, but change their clothes to match the style of image 2."

---

## Tier Selection Guidance

| Tier | Cost | Use When |
|-------|-------|-----------|
| **iterate** | FREE (CF) / $0.005-0.008/MP | Quick drafts, many variations, testing concepts |
| **default** | $0.008/MP | Daily driver, balanced quality/speed |
| **premium** | $0.03/MP | Final assets, client deliverables, high fidelity |
| **max** | $0.06-0.07/MP | Critical work, SOTA quality, multi-reference composition |

**Rule of Thumb**:
- Iterate → **10+ variations** to explore
- Default → **3-5 variations** for final selection
- Premium → **1-2 refinements** for production
- Max → **Single critical deliverable** where failure is unacceptable

---

## Aspect Ratios & Composition

### Common Ratios

| Ratio | Best For | Example Usage |
|--------|-----------|---------------|
| **1:1** (1024x1024) | Portraits, logos, icons | Profile pictures, brand marks |
| **16:9** (1920x1080) | Landscapes, presentations | Hero images, social media |
| **9:16** (1080x1920) | Stories, mobile portraits | Instagram stories, phone wallpapers |
| **4:5** (816x1024) | Documents, print | Book covers, ads |

### Positioning Subjects

**Important**: Subject position affects rendering quality. Place subject descriptions **early** in prompt:

> "A red sports car speeding..." (car is subject, comes first)
> "...on a coastal highway at sunset" (context comes last)

---

## Prompt Libraries & Resources

### Curated Databases

- **[All-Image-Prompts](https://github.com/junxiaopang/all-image-prompts)**: Multi-model search (Flux, MJ, Grok) with modern web interface
- **[Civitai Prompts](https://civitai.com/models)**: Open source model prompting, includes full generation metadata for Flux styles
- **[Lexica.art](https://lexica.art)**: Visual search for cinematic and realistic prompts
- **[PromptHero](https://prompthero.com)**: DALL-E 3 and Midjourney dedicated sections

### Specialized Collections

- **[FLUX.1-pro Cheatsheet](https://github.com/AWTom/FLUX.1-pro-cheatsheet)**: Artist styles for 904 distinct artists
- **[Kiko Flux 2 Prompt Builder](https://github.com/ComfyAssets/kiko-flux2-prompt-builder)**: JSON-style builder with camera/lens/lighting presets
- **[Logo Design Prompts](https://github.com/friuns2/BlackFriday-GPTs-Prompts)**: Minimalist, vector, 3D logo templates

### Learning Resources

- **[LearnPrompt](https://www.learnprompt.pro)**: Systematic tutorials updated for 2026 standards
- **[Fal.ai Learn](https://fal.ai/learn/devs)**: Official Flux.2, Recraft V3, Ideogram V2 documentation

### Official Documentation

- **[Flux.2 Guide](https://fal.ai/learn/devs/flux-2-prompt-guide)**: (Dec 2025)
- **[Flux.2 Max Guide](https://fal.ai/learn/devs/flux-2-max-prompt-guide)**: (Dec 19, 2025)
- **[Flux.2 Turbo Guide](https://fal.ai/learn/devs/flux-2-turbo-prompt-guide)**: (Jan 7, 2026)
- **[Recraft V3 Docs](https://www.recraft.ai/docs/recraft-models/recraft-V3)**: (Jan 2026)
- **[Ideogram V2 Docs](https://docs.ideogram.ai/using-ideogram/prompting-guide)**: (Late 2025)

---

## Error Recovery & Best Practices

### Error Codes

Scripts return structured error codes for programmatic handling:

| Code | Meaning | Fix |
|------|---------|-----|
| `CF_AUTH_MISSING` | Cloudflare API keys not configured | Add `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` to `.env` |
| `CF_QUOTA_EXCEEDED` | Daily limit reached (~96/day) | Wait until midnight UTC or use `default` tier |
| `CF_RATE_LIMIT` | Too many requests in short period | Wait 60s and retry |
| `CF_ERROR` | General Cloudflare API error | Check error message for details |
| `FAL_AUTH_INVALID` | Invalid or missing API key | Check `FAL_API_KEY` in `.env` |
| `FAL_CREDITS_EXHAUSTED` | No credits remaining | Add credits at [fal.ai/dashboard](https://fal.ai/dashboard) |
| `FAL_RATE_LIMIT` | Rate limit hit | Wait 60s and retry |
| `FAL_JOB_TIMEOUT` | Job took too long | Retry or use faster tier |
| `FAL_NO_IMAGE` | No image in response | Retry with different prompt |
| `FAL_ERROR` | General Fal.ai API error | Check error message for details |

### Exit Codes

| Exit Code | Meaning | Retryable |
|-----------|---------|-----------|
| 0 | Success | N/A |
| 1 | General error | Maybe |
| 2 | Config/auth error | No (fix config first) |
| 3 | Resource limit (quota/rate) | Yes (after waiting) |

### Provider Fallback

**Important Change (v2.0)**: Cloudflare quota exceeded errors (CF_QUOTA_EXCEEDED, CF_RATE_LIMIT) now **do NOT fall back** to Fal.ai. This prevents accidentally consuming paid credits when you intended to use the FREE tier.

**Previous Behavior**: Any Cloudflare failure triggered fallback
**New Behavior**: Only non-quota errors trigger fallback

**Handling Fallback**:
```bash
# If Cloudflare fails with non-quota error, output shows:
"Cloudflare failed, falling back to fal.ai flux-2/flash..."

# If Cloudflare quota exceeded, output shows:
"❌ Cloudflare FREE quota exceeded for today"
# Script exits with code 3, NO fallback
```

**Retry Strategy**:
1. First attempt: Cloudflare (iterate tier)
2. If quota exceeded: Exit with code 3, suggest using `default` tier
3. If other failure: Automatic fallback to Fal.ai flux-2/flash
4. If Fal.ai fails: Check API key configuration in `.env`

### Common Issues

| Issue | Cause | Solution |
|--------|---------|----------|
| **Text garbled** | Text not in quotes (Ideogram) or too long | Use quotation marks, chunk complex text |
| **Wrong colors** | Vague color names | Use HEX codes: #FF5733 |
| **Blurry output** | Low guidance scale or poor lighting description | Add "sharp focus", describe lighting quality |
| **API rate limit** | Too many Cloudflare requests | Switch to default tier or use Fal.ai |
| **No image generated** | Cloudflare API keys missing | Check CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN in `.env` |

---

## Quick Reference

### Flux.2 Command Cheat Sheet

```bash
# Basic
bun scripts/gen.ts "a sunset over mountains" -t default

# With precise color
bun scripts/gen.ts "A red sports car #FF0000" -t pro

# JSON prompt (Pro/Max only - via API)
# Requires manual JSON structure in scripts/lib/config.ts or direct API call

# Text/logo
bun scripts/gen.ts '"SALE" in bold neon text' --text

# Vector output
bun scripts/gen.ts "logo design" --text --svg
```

### Editing Command Cheat Sheet

```bash
# Simple edit
bun scripts/edit.ts photo.jpg "change sky to purple"

# Inpainting
bun scripts/edit.ts photo.jpg "add sunglasses" --mask mask.png

# Multi-reference (auto max tier)
bun scripts/edit.ts photo.jpg "match this style" --ref style1.jpg --ref style2.jpg
```

---

## Summary of 2025-2026 Changes

| Old Approach (2023-2024) | Modern Approach (2025-2026) |
|----------------------------|----------------------------|
| Keyword tags, weights like `(Subject:1.5)` | Natural prose or Structured JSON |
| "Blue shirt, red car" (often bleeds) | "Shirt #0000FF, Car #FF0000" |
| Negative prompts: "no blur" | Positive description: "sharp focus throughout" |
| Character LoRAs, FaceSwap | Omni Reference, Personalization |
| Garbled text requiring inpainting | Native high-fidelity rendering |

**Takeaway**: Focus on **descriptive precision**, **hierarchical structure**, and **positive framing** over negative constraints.

---

## Testing

### Verify Output Directory Fix

The OUTPUT_DIR bug was fixed in v2.0. Images now always save to repo root regardless of working directory.

```bash
# Test 1: Run from repo root
cd /path/to/repo
bun scripts/gen.ts "test sunset" -t iterate
# Expected: Image saved to /path/to/repo/.ada/data/images/

# Test 2: Run from subdirectory (MUST work)
cd /path/to/repo/content/skills
bun ../../content/skills/image-generation/scripts/gen.ts "test mountains" -t iterate
# Expected: Image saved to /path/to/repo/.ada/data/images/ (NOT subdirectory)

# Verify
ls -la /path/to/repo/.ada/data/images/
```

### Verify Error Handling

```bash
# Test 1: Missing Cloudflare keys
unset CLOUDFLARE_ACCOUNT_ID
bun scripts/gen.ts "test" -t iterate
# Expected: Clear error message with setup instructions, exit code 2

# Test 2: Missing Fal.ai key
unset FAL_API_KEY
bun scripts/gen.ts "test" -t default
# Expected: Clear error message with setup instructions, exit code 2

# Test 3: Verify exit codes
bun scripts/gen.ts "test" -t iterate; echo "Exit code: $?"
# Expected: Exit code 0 (success), 1 (error), 2 (config), or 3 (quota)
```

### Full Feature Test Suite

```bash
# Generation - Cloudflare FREE tier
bun scripts/gen.ts "a sunset over mountains, golden hour, dramatic clouds" -t iterate

# Generation - Fal.ai default tier
bun scripts/gen.ts "cyberpunk city at night, neon lights, rain-slicked streets" -t default

# Generation - Text/logo specialist
bun scripts/gen.ts '"ACME" in bold modern font, blue gradient background' --text

# Editing
bun scripts/edit.ts /path/to/photo.jpg "change the sky to purple sunset"

# Upscaling
bun scripts/upscale.ts /path/to/image.jpg -t default --scale 2

# Background removal
bun scripts/rembg.ts /path/to/photo.jpg
```
