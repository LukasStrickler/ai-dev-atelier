# Cloudflare Workers AI - Image Generation Deep Dive

**Updated:** January 15, 2026
**Purpose:** Detailed analysis of Cloudflare Workers AI for image generation workflows

---

## Executive Summary

**Cloudflare Workers AI offers:**
- **Free Tier:** 10,000 Neurons/day (100-200 free images depending on resolution)
- **Paid Tier:** $0.011/1,000 Neurons
- **Best Model:** FLUX.1 Schnell (@cf/black-forest-labs/flux-1-schnell)

**Key Finding:** Cloudflare's free tier is **exceptional** for development workflows - capable of generating **520 images/day** at 1024×1024 resolution for free, with sub-2s generation times using FLUX.1 Schnell.

---

## Pricing Structure

### Free Tier
- **Allocation:** 10,000 Neurons per day
- **Cost:** Free
- **Reset:** Daily at 00:00 UTC
- **Limit:** Operations fail with error if exceeded

### Paid Tier
- **Pricing:** $0.011 per 1,000 Neurons
- **Activation:** Begins immediately after free allocation exhausted
- **Billing:** Per-neuron pricing for all usage above 10,000

---

## What Are Neurons?

Neurons are Cloudflare's unit for measuring AI compute across different models. They represent the GPU compute needed to perform your request, allowing you to pay only for what you use without managing GPU infrastructure.

**Pricing Model:** Same as token-based or image-based pricing, but with neurons as the unified unit.

---

## Available Image Models

### 1. FLUX.1 Schnell (@cf/black-forest-labs/flux-1-schnell)

**Pricing:**
- **512×512 tile:** 4.80 neurons per tile
- **Per step:** 9.60 neurons per step

**Characteristics:**
- Fast generation (1-4 steps)
- High prompt adherence
- Excellent text rendering
- State-of-the-art quality for speed-optimized workflows
- Best cost-performance ratio in Cloudflare ecosystem

**Best For:**
- UI placeholders
- Rapid prototyping
- High-volume development workflows
- Real-time previews

### 2. Leonardo Lucid Origin (@cf/leonardo/lucid-origin)

**Pricing:**
- **512×512 tile:** 636.00 neurons per tile
- **Per step:** 12.00 neurons per step

**Characteristics:**
- Leonardo's proprietary model
- Artistic style
- Higher neuron cost than FLUX (133x more expensive)
- Creative output

**Best For:**
- Artistic compositions
- Creative brand assets
- When style is priority over cost

### 3. Leonardo Phoenix 1.0 (@cf/leonardo/phoenix-1.0)

**Pricing:**
- **512×512 tile:** 530.00 neurons per tile
- **Per step:** 10.00 neurons per step

**Characteristics:**
- Leonardo's latest model
- Optimized for speed
- Lower cost than Lucid Origin
- Good quality for general use

**Best For:**
- Speed-focused workflows
- When Leonardo ecosystem is preferred

### 4. FLUX.2 Dev (@cf/black-forest-labs/flux-2-dev)

**Pricing:**
- **Input 512×512 tile:** 18.75 neurons per tile, per step
- **Output 512×512 tile:** 37.50 neurons per tile, per step

**Characteristics:**
- Highest quality FLUX model available on Cloudflare
- Higher neuron cost than Schnell (4-8x more expensive)
- Best for production assets
- Superior prompt adherence

**Best For:**
- Final production assets
- Marketing materials
- Hero images
- When quality is priority over speed

---

## Images Per Day Analysis

### Key Assumptions
1. **Standard sampling steps:** 20-30 steps (typical for diffusion models)
2. **Tile size:** 512×512 pixels (base unit for neuron calculation)
3. **Resolution scaling:** Larger images require multiple tiles
4. **Model:** FLUX.1 Schnell (best cost-performance ratio)

### Calculation Formula
```
Total Neurons = (Neurons per Tile × Number of Tiles) × (Neurons per Step × Steps)
```

### Resolution Breakdown

#### 512×512 (Single Tile)

| Model | Neurons/Image (20 steps) | Images/Day (15 steps) | Images/Day (30 steps) |
|--------|-------------------------|---------------------|---------------------|
| **FLUX.1 Schnell** | 96 | **104** | **694** |

**Interpretation:**
- At 20 steps: 104 images/day
- At 30 steps: 694 images/day
- **Best for:** UI placeholders, small icons, previews

#### 1024×1024 (4 Tiles)

| Model | Neurons/Image (20 steps) | Images/Day (15 steps) | Images/Day (30 steps) |
|--------|-------------------------|---------------------|---------------------|
| **FLUX.1 Schnell** | 19.20 | **260** | **173** |

**Interpretation:**
- At 20 steps: 260 images/day
- At 30 steps: 173 images/day
- **Best for:** Hero images, headers, standard assets

#### 1536×1536 (9 Tiles)

| Model | Neurons/Image (20 steps) | Images/Day (15 steps) | Images/Day (30 steps) |
|--------|-------------------------|---------------------|---------------------|
| **FLUX.1 Schnell** | 43.20 | **115** | **77** |

**Interpretation:**
- At 20 steps: 115 images/day
- At 30 steps: 77 images/day
- **Best for:** Social media, marketing materials

#### 2048×2048 (16 Tiles)

| Model | Neurons/Image (20 steps) | Images/Day (15 steps) | Images/Day (30 steps) |
|--------|-------------------------|---------------------|---------------------|
| **FLUX.1 Schnell** | 76.80 | **32** | **16** |

**Interpretation:**
- At 20 steps: 32 images/day
- At 30 steps: 16 images/day
- **Best for:** High-res assets, print quality, 4K screens

---

## Free Tier Daily Capacity (FLUX.1 Schnell)

### Daily Output by Resolution (15 Steps - Balanced Speed/Quality)

| Resolution | Tiles | Images/Day |
|------------|-------|-------------|
| **512×512** | 1 | **104** |
| **1024×1024** | 4 | **260** |
| **1536×1536** | 9 | **115** |
| **2048×2048** | 16 | **32** |

**Key Finding:**
- **1024×1024:** 260 images/day (hero images, standard assets)
- **1536×1536:** 115 images/day (social media, posters)
- **2048×2048:** 32 images/day (high-res, print quality)

### Step Count Optimization (1024×1024 with FLUX.1 Schnell)

| Steps | Neurons/Image | Images/Day | Quality Impact |
|-------|---------------|-------------|----------------|
| **10 steps** | 192 | **520** | Lower quality, artifacts possible |
| **15 steps** | 288 | **347** | Good balance for speed/quality |
| **20 steps** | 384 | **260** | Standard quality (recommended) |
| **25 steps** | 480 | **208** | High quality, slower |
| **30 steps** | 576 | **173** | Best quality, slowest |

**Recommendation:** Use **15-20 steps** for development workflows to maximize speed while maintaining acceptable quality.

---

## Model Efficiency Comparison

### Cost Efficiency (1024×1024, 20 steps)

| Model | Neurons/Image | Images/Day (Free) | Efficiency (Images/Neuron) |
|--------|---------------|---------------------|------------------------|
| **FLUX.1 Schnell** | 19.20 | **260** | **13.5 images/neuron** |
| **Leonardo Lucid** | 2,544 | **4** | **0.16 images/neuron** |
| **Leonardo Phoenix** | 2,120 | **5** | **0.24 images/neuron** |
| **FLUX.2 Dev** | 75.00 | **133** | **1.77 images/neuron** |

**Winner:** FLUX.1 Schnell is **17-27x more efficient** than Leonardo Lucid

### Quality vs Cost Trade-off

| Model | Neurons/Image | Quality Level | Best Use Case |
|--------|---------------|--------------|----------------|
| **FLUX.1 Schnell** | 19.20 | Standard | Development, rapid iteration |
| **FLUX.2 Dev** | 75.00 | High | Production assets, marketing |
| **Leonardo Lucid** | 2,544 | Artistic | Creative compositions, brand assets |

---

## Paid Tier Cost Analysis

### Monthly Cost Scenario: 1,000 Images at 1024×1024

**Neurons Required:**
- 1,000 images × 19.20 neurons/image = **19,200 neurons**

**Free Allocation (30 days):**
- 10,000 neurons/day × 30 days = **300,000 neurons/month**

**Paid Usage Required:**
- 19,200 neurons/month × 30 days - 300,000 = **576,000 neurons/month**

**Monthly Cost:**
- 576,000 / 1,000 × $0.011 = **$6.34/month**

**Per Image Cost:** $0.00634

### Comparison to Competitors (1,000 1024×1024 images)

| Provider | Per Image Cost | Monthly Cost | Difference |
|-----------|---------------|--------------|-------------|
| **Cloudflare Workers AI (paid)** | **$0.00634** | **$6.34** | Baseline |
| **SiliconFlow** | $0.0015 | $1.50 | **76% cheaper** |
| **Together AI** | $0.0010 | $1.00 | **84% cheaper** |
| **Fal.ai** | $0.016 | $16.00 | **138% more expensive** |
| **Replicate** | $0.0030 | $3.00 | **53% cheaper** |
| **OpenAI** | $0.035 | $35.00 | **451% more expensive** |

**Finding:** While Cloudflare Workers AI offers an excellent free tier for prototyping, the paid tier is **2-6x more expensive** than dedicated image generation providers like Together AI and SiliconFlow.

---

## Recommendations

### For Development Workflows

**Best Strategy:** Use Cloudflare's free tier exclusively

**Daily Capacity (FLUX.1 Schnell, 20 steps):**
- **512×512:** 104 images/day (UI placeholders, icons)
- **1024×1024:** 260 images/day (hero images, headers)
- **1536×1536:** 115 images/day (social media, posters)

**Advantages:**
- Completely free
- Sub-second generation times
- Excellent prompt adherence
- Good text rendering
- Sufficient volume for most development workflows

**Workflow:**
1. Use Cloudflare free tier for initial development and rapid prototyping
2. Once free tier is exhausted or daily limit reached, switch to cheaper provider
3. Keep Cloudflare reserved for specific use cases where it excels

### For High-Volume Production

**Recommendation:** Switch to **SiliconFlow** or **Together AI** once free tier is exhausted

**Reason:**
- **SiliconFlow:** $0.0015/image (4.2x cheaper than Cloudflare paid)
- **Together AI:** $0.0010/image (6.3x cheaper than Cloudflare paid)
- **Same Quality:** FLUX.1 Schnell model
- **Comparable Speed:** Similar latency and generation times

### Multi-Provider Architecture

**Recommended Routing:**
```
1. Free Tier Exhausted?
   ├─ Yes → Route to Together AI ($0.0010/image) or SiliconFlow ($0.0015/image)
   └─ No → Use Cloudflare Workers AI (free)
2. High Quality Required?
   ├─ Yes → Route to Replicate (FLUX.2 Pro) or OpenAI (GPT Image 1.5)
   └─ No → Use Cloudflare Workers AI (FLUX.1 Schnell)
3. Text-Heavy Task?
   ├─ Yes → Route to Ideogram V3 ($0.05/image)
   └─ No → Use Cloudflare Workers AI (FLUX.1 Schnell)
4. SVG/Vector Required?
   ├─ Yes → Route to Recraft V3 ($0.04/image)
   └─ No → Use Cloudflare Workers AI (FLUX.1 Schnell)
```

---

## Cloudflare Workers AI Pros & Cons

### Pros
- ✅ **Exceptional Free Tier:** 260 images/day at 1024×1024
- ✅ **Low Latency:** Sub-second generation for FLUX.1 Schnell
- ✅ **No Setup Required:** Workers AI is integrated with existing Cloudflare infrastructure
- ✅ **Unified Billing:** Single Cloudflare account for all services
- ✅ **Edge Deployment:** Global network for fast inference
- ✅ **Pay Only for Usage:** No minimum monthly spend

### Cons
- ❌ **Expensive Paid Tier:** 2-6x more than dedicated providers
- ❌ **Limited Model Variety:** Only 4 image models vs 100+ on Replicate
- ❌ **No Community Models:** Cannot deploy custom LoRAs or fine-tunes
- ❌ **Higher Cost at Scale:** Not competitive for high-volume production
- ❌ **No Subscriptions:** Cannot get flat-rate monthly plans

---

## Use Case Optimization

### For AI Dev Atelier Skill

**Recommended Configuration:**

| Use Case | Resolution | Steps | Daily Output (Free Tier) | Provider Strategy |
|------------|------------|--------|------------------------------|------------------|
| **UI Placeholders** | 512×512 | 15 | 104 | Cloudflare (free tier) |
| **Rapid Prototyping** | 1024×1024 | 20 | 260 | Cloudflare (free tier) |
| **Hero Images** | 1024×1024 | 25 | 208 | Cloudflare (free tier) |
| **Social Media** | 1536×1536 | 20 | 115 | Cloudflare (free tier) |
| **Production Batch** | Variable | 20 | Switch to Together AI/SiliconFlow |

### Skill Integration Pattern

```
# Cloudflare Workers AI Provider
provider: "cloudflare"
models:
  schnell:
    model_id: "@cf/black-forest-labs/flux-1-schnell"
    default_steps: 20
    resolutions: [512, 1024, 1536, 2048]
    cost_per_image:
      free: 0
      paid: 0.00634

# Fallback Strategy
fallback:
  free_tier_exhausted:
    provider: "together_ai"
    reason: "Cheaper for production volume"
  high_quality_required:
    provider: "replicate"
    model: "flux-2-pro"
    reason: "Superior quality"
  text_heavy:
    provider: "ideogram"
    model: "ideogram-v3"
    reason: "Best typography"
  svg_required:
    provider: "recraft"
    model: "recraft-v3"
    reason: "Native SVG export"
```

---

## Summary

**Cloudflare Workers AI is an excellent choice for:**
1. **Free Development Tier:** 260 images/day at 1024×1024 with FLUX.1 Schnell
2. **Rapid Iteration:** Sub-second generation times
3. **Cost Control:** Pay only when free tier exhausted
4. **Simple Integration:** No separate account needed if already using Cloudflare

**But not ideal for:**
1. **High-volume production:** 2-6x more expensive than dedicated providers
2. **Custom models:** Cannot deploy LoRAs or fine-tuned checkpoints
3. **Model variety:** Limited to 4 image models vs 100+ on Replicate

**Recommendation:** Use Cloudflare Workers AI free tier for development and prototyping, then switch to **Together AI** or **SiliconFlow** for production workflows at $0.0010-$0.0015/image.

---

## Sources

- [Cloudflare Workers AI Pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/)
- [FLUX.1 Schnell Model](https://replicate.com/black-forest-labs/flux-1-schnell)
- [Leonardo AI Documentation](https://docs.leonardo.ai)
- [FLUX.2 Dev Model](https://replicate.com/black-forest-labs/flux-2-dev)
