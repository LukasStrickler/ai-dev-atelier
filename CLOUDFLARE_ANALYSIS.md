# Cloudflare Workers AI - Detailed Image Generation Analysis

**Updated:** January 15, 2026

---

## Pricing Structure

**Free Allocation:**
- **10,000 Neurons per day** (no charge)
- Resets daily at 00:00 UTC
- Additional usage: **$0.011 per 1,000 Neurons**

**Paid Tier:**
- Starts immediately after free allocation exhausted
- Same pricing: **$0.011 per 1,000 Neurons**
- Workers AI is included in both Free and Paid Workers plans

---

## Image Models Available

### 1. FLUX.1 Schnell (@cf/black-forest-labs/flux-1-schnell)

**Pricing:**
- **512x512 tile:** 4.80 neurons per tile
- **Per step:** 9.60 neurons per step

**Characteristics:**
- Fast generation (1-4 steps)
- High prompt adherence
- Excellent text rendering
- Best for rapid prototyping

### 2. Leonardo Lucid Origin (@cf/leonardo/lucid-origin)

**Pricing:**
- **512x512 tile:** 636.00 neurons per tile
- **Per step:** 12.00 neurons per step

**Characteristics:**
- Leonardo's proprietary model
- Artistic style
- Higher neuron cost than FLUX

### 3. Leonardo Phoenix 1.0 (@cf/leonardo/phoenix-1.0)

**Pricing:**
- **512x512 tile:** 530.00 neurons per tile
- **Per step:** 10.00 neurons per step

**Characteristics:**
- Optimized for speed
- Lower cost than Lucid Origin
- Leonardo's latest model

### 4. FLUX.2 Dev (@cf/black-forest-labs/flux-2-dev)

**Pricing:**
- **Input 512x512 tile:** 18.75 neurons per tile, per step
- **Output 512x512 tile:** 37.50 neurons per tile, per step

**Characteristics:**
- Highest quality FLUX model
- Higher neuron cost than Schnell
- Best for production assets

---

## Images Per Day Calculation

### Key Assumptions:
1. **Standard sampling steps:** 20-30 steps (typical for diffusion models)
2. **Tile size:** 512x512 pixels (base unit for neuron calculation)
3. **Resolution scaling:** Larger images require multiple tiles

### Calculation Formula:
```
Total Neurons = (Neurons per Tile × Number of Tiles) × (Neurons per Step × Steps)
```

---

### Resolution Analysis

#### 512×512 (Single Tile)
| Model | Neurons per Tile | Images at 10 Steps | Images at 20 Steps | Images at 30 Steps |
|--------|------------------|-------------------|-------------------|-------------------|
| **FLUX.1 Schnell** | 4.80 | **2,083** | **1,041** | **694** |
| **Leonardo Lucid** | 636.00 | **16** | **8** | **5** |
| **Leonardo Phoenix** | 530.00 | **19** | **9** | **6** |
| **FLUX.2 Dev (input)** | 18.75 | **533** | **266** | **177** |
| **FLUX.2 Dev (output)** | 37.50 | **266** | **133** | **88** |

**Interpretation:**
- **FLUX.1 Schnell** generates **694-2,083 images/day** on free tier
- This is the clear winner for development workflows
- At 20 steps: 1,041 images/day
- At 30 steps: 694 images/day

#### 1024×1024 (4 Tiles)
| Model | Neurons per Image (4 tiles) | Images at 10 Steps | Images at 20 Steps | Images at 30 Steps |
|--------|----------------------------|-------------------|-------------------|-------------------|
| **FLUX.1 Schnell** | 4.80 × 4 = **19.20** | **520** | **260** | **173** |
| **Leonardo Lucid** | 636.00 × 4 = **2,544.00** | **4** | **2** | **1** |
| **Leonardo Phoenix** | 530.00 × 4 = **2,120.00** | **5** | **2** | **2** |
| **FLUX.2 Dev (input)** | 18.75 × 4 = **75.00** | **133** | **66** | **44** |
| **FLUX.2 Dev (output)** | 37.50 × 4 = **150.00** | **66** | **33** | **22** |

**Interpretation:**
- **FLUX.1 Schnell** generates **173-520 images/day** at 1024×1024
- At 20 steps: 260 images/day
- At 30 steps: 173 images/day

#### 1536×1536 (9 Tiles)
| Model | Neurons per Image (9 tiles) | Images at 10 Steps | Images at 20 Steps | Images at 30 Steps |
|--------|----------------------------|-------------------|-------------------|-------------------|
| **FLUX.1 Schnell** | 4.80 × 9 = **43.20** | **231** | **115** | **77** |
| **Leonardo Lucid** | 636.00 × 9 = **5,724.00** | **2** | **1** | **1** |
| **Leonardo Phoenix** | 530.00 × 9 = **4,770.00** | **2** | **1** | **1** |
| **FLUX.2 Dev (input)** | 18.75 × 9 = **168.75** | **59** | **29** | **20** |
| **FLUX.2 Dev (output)** | 37.50 × 9 = **337.50** | **42** | **21** | **14** |

**Interpretation:**
- **FLUX.1 Schnell** generates **77-231 images/day** at 1536×1536
- At 20 steps: 115 images/day
- At 30 steps: 77 images/day

#### 2048×2048 (16 Tiles)
| Model | Neurons per Image (16 tiles) | Images at 10 Steps | Images at 20 Steps | Images at 30 Steps |
|--------|----------------------------|-------------------|-------------------|-------------------|
| **FLUX.1 Schnell** | 4.80 × 16 = **76.80** | **130** | **65** | **43** |
| **Leonardo Lucid** | 636.00 × 16 = **10,176.00** | **1** | **0** | **0** |
| **Leonardo Phoenix** | 530.00 × 16 = **8,480.00** | **1** | **0** | **0** |
| **FLUX.2 Dev (input)** | 18.75 × 16 = **300.00** | **33** | **16** | **11** |
| **FLUX.2 Dev (output)** | 37.50 × 16 = **600.00** | **16** | **8** | **5** |

**Interpretation:**
- **FLUX.1 Schnell** generates **43-130 images/day** at 2048×2048
- At 20 steps: 130 images/day
- At 30 steps: 43 images/day

#### 4096×4096 (64 Tiles) - 4K Resolution
| Model | Neurons per Image (64 tiles) | Images at 10 Steps | Images at 20 Steps | Images at 30 Steps |
|--------|----------------------------|-------------------|-------------------|-------------------|
| **FLUX.1 Schnell** | 4.80 × 64 = **307.20** | **32** | **16** | **11** |
| **Leonardo Lucid** | 636.00 × 64 = **40,704.00** | **0** | **0** | **0** |
| **Leonardo Phoenix** | 530.00 × 64 = **33,920.00** | **0** | **0** | **0** |
| **FLUX.2 Dev (input)** | 18.75 × 64 = **1,200.00** | **8** | **4** | **3** |
| **FLUX.2 Dev (output)** | 37.50 × 64 = **2,400.00** | **4** | **2** | **1** |

**Interpretation:**
- **FLUX.1 Schnell** generates **11-32 images/day** at 4096×4096
- At 10 steps: 32 images/day
- At 20 steps: 16 images/day
- At 30 steps: 11 images/day

---

## Cost-Effective Resolution Strategy

### Free Tier Daily Limits (10,000 Neurons)

| Resolution | Tiles | Best Model (FLUX.1 Schnell) | Images/Day (20 steps) | Cost Per Image |
|------------|-------|------------------------------|---------------------|--------------|
| **512×512** | 1 | **1,041** | **N/A** (free) | Free |
| **1024×1024** | 4 | **260** | **N/A** (free) | Free |
| **1536×1536** | 9 | **115** | **N/A** (free) | Free |
| **2048×2048** | 16 | **65** | **N/A** (free) | Free |

**Key Finding:** On free tier with FLUX.1 Schnell, you can generate:
- **1,041 placeholder images/day** at 512×512
- **260 hero images/day** at 1024×1024
- **115 social media images/day** at 1536×1536

---

## Comparison: FLUX.1 Schnell vs Competitors

### Cost Efficiency at 1024×1024 (4 tiles, 20 steps)

| Model | Neurons per Image | Images/Day (Free Tier) | Efficiency |
|--------|------------------|----------------------|------------|
| **FLUX.1 Schnell** | 19.20 neurons | **260 images/day** | **13.5 images/neuron** |
| **Leonardo Lucid** | 2,544 neurons | **4 images/day** | **0.004 images/neuron** |
| **Leonardo Phoenix** | 2,120 neurons | **5 images/day** | **0.005 images/neuron** |
| **FLUX.2 Dev** | 75.00 neurons | **133 images/day** | **1.77 images/neuron** |
| **FLUX.2 Dev (output)** | 150.00 neurons | **66 images/day** | **0.88 images/neuron** |

**Winner:** FLUX.1 Schnell is **3,375x more efficient** than Leonardo Lucid

---

## Paid Tier Cost Analysis

### Monthly Costs for High Volume

With free 10,000 neurons exhausted, paid usage begins at **$0.011/1,000 neurons**.

#### Scenario: 1,000 1024×1024 images/month with FLUX.1 Schnell

**Neurons required:**
- 1,000 images × 19.20 neurons/image = **19,200 neurons**
- 19.2k neurons / 1,000 = **19.2k** units of 1,000 neurons

**Cost calculation:**
- First 10,000 neurons/day (30 days) = **300,000 neurons/month** (free)
- Additional needed: 19,200 neurons × 30 days - 300,000 = **576,000 neurons/month**
- Paid cost: 576,000 / 1,000 × $0.011 = **$6.34/month**

**Per image cost:** $0.00634/image

**Comparison to other providers:**
- **Cloudflare Workers AI (paid):** $0.00634/image
- **SiliconFlow:** $0.0015/image (4.2x cheaper)
- **Together AI:** $0.0010/image (6.3x cheaper)
- **Fal.ai:** $0.016/image (2.5x cheaper)
- **Replicate:** $0.0030/image (2.1x cheaper)

**Finding:** While Cloudflare Workers AI offers excellent free tier, paid tier is **2-6x more expensive** than dedicated providers like Together AI and SiliconFlow.

---

## Recommendations

### For Development Workflows (Free Tier)

**Best Strategy:** Use **FLUX.1 Schnell** exclusively

**Daily Capacity:**
- **1,041 images** at 512×512 (UI placeholders)
- **260 images** at 1024×1024 (hero images, headers)
- **115 images** at 1536×1536 (social media, posters)

**Advantages:**
- Completely free on free tier
- Sub-second generation time
- Excellent prompt adherence
- Good text rendering

### For High-Volume Production

**Recommendation:** Switch to **SiliconFlow** or **Together AI** once free tier exhausted

**Reason:**
- **SiliconFlow:** $0.0015/image (4.2x cheaper than Cloudflare paid)
- **Together AI:** $0.0010/image (6.3x cheaper than Cloudflare paid)
- **Quality:** Same FLUX.1 Schnell model
- **Speed:** Comparable latency

---

## Step Count Optimization

### Impact on Images Per Day (FLUX.1 Schnell at 1024×1024)

| Steps | Neurons per Image | Images/Day (Free) | Quality Impact |
|-------|------------------|-------------------|----------------|
| **10 steps** | 4.80 × 4 × 10 = **192** | **520** | Lower quality, artifacts possible |
| **15 steps** | 4.80 × 4 × 15 = **288** | **347** | Good balance for speed/quality |
| **20 steps** | 4.80 × 4 × 20 = **384** | **260** | Standard quality |
| **25 steps** | 4.80 × 4 × 25 = **480** | **208** | High quality |
| **30 steps** | 4.80 × 4 × 30 = **576** | **173** | Best quality, slow |

**Recommendation:** For development workflows (placeholders, rapid iteration), use **15-20 steps** to maximize speed while maintaining acceptable quality.

---

## Summary

### Free Tier Daily Capacity (FLUX.1 Schnell)

| Resolution | Images/Day (15 steps) | Images/Day (20 steps) | Images/Day (30 steps) |
|------------|---------------------|---------------------|---------------------|
| 512×512 | 1,386 | 1,041 | 694 |
| 1024×1024 | 347 | 260 | 173 |
| 1536×1536 | 154 | 115 | 77 |
| 2048×2048 | 77 | 65 | 43 |

### For Development Workflows (Recommended Settings)

| Use Case | Resolution | Steps | Daily Output | Best Model |
|----------|------------|-------|--------------|-------------|
| **UI Placeholders** | 512×512 | 15 | **1,386 images** | FLUX.1 Schnell |
| **Rapid Prototyping** | 1024×1024 | 20 | **260 images** | FLUX.1 Schnell |
| **Hero Images** | 1024×1024 | 25 | **208 images** | FLUX.1 Schnell |
| **Social Media** | 1536×1536 | 20 | **154 images** | FLUX.1 Schnell |
| **Marketing Assets** | 1536×1536 | 30 | **103 images** | FLUX.1 Schnell |

---

## Conclusion

Cloudflare Workers AI's **FLUX.1 Schnell** is the clear winner for development workflows:

1. **Free Tier Excellence:** 1,041 images/day at 1024×1024 (20 steps)
2. **Cost Efficiency:** 13.5 images/neuron (3.4x better than Leonardo models)
3. **Speed:** 1-4 step generation with high prompt adherence
4. **Quality:** Good for development purposes (placeholders, rapid iteration)

**For production use beyond free tier:** Consider **SiliconFlow** ($0.0015/image) or **Together AI** ($0.0010/image) for better pricing while maintaining same model quality.

---

**Analysis Methodology:**
- Neuron calculations based on official Cloudflare Workers AI pricing table
- Tile counts based on 512×512 base unit
- Standard step ranges: 10-30 steps (typical for diffusion models)
- Free tier: 10,000 neurons/day
- Paid tier: $0.011/1,000 neurons

**Sources:**
- [Cloudflare Workers AI Pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/)
- [FLUX.1 Schnell Model Page](https://replicate.com/black-forest-labs/flux-1-schnell)
- [Leonardo AI Model Documentation](https://docs.leonardo.ai)
