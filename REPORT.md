# Image Generation Models Research Report (January 2026)

**Research Date:** January 15, 2026
**Purpose:** Identify best image generation models for AI Dev Atelier skill development
**Focus:** Cost-effective, fast, production-ready models for development workflows

---

## Executive Summary

The 2025-2026 image generation landscape has matured into a **two-tiered ecosystem**:

1. **Turbo/Distilled Models** (<$0.01/image, <3s latency) - Ideal for rapid prototyping, UI placeholders, and high-volume development workflows
2. **Premium Models** ($0.02-$0.15/image, 5-15s latency) - For final production assets, marketing materials, and complex creative work

**Key Finding:** The sweet spot for development workflows is **FLUX.1 Schnell** and **Z-Image Turbo** at **$0.0015-$0.003 per image** with sub-2s generation times.

---

## 1. Model Comparison Matrix

### Top-Tier Production Models (Quality-Focused)

| Model | Provider | Cost/Image | Speed | Text Accuracy | Strength | Best For |
|--------|-----------|-------------|---------|-----------|-----------|---|
| **GPT Image 1.5** | OpenAI | $0.035-$0.05 | ~94% | Prompt adherence, multi-turn editing | Complex scenes, high-context work |
| **Nano Banana Pro** | Google | $0.04-$0.08 | ~93% | Realism, grounding search | Brand mockups, photorealistic UI |
| **FLUX.2 [max]** | Black Forest Labs | $0.04-$0.05 | ~95% | Visual grounding, 2K resolution | Hero images, marketing assets |
| **GLM-Image** | Z.AI | $0.02-$0.04 | ~95% | Knowledge density, bilingual | Technical diagrams, multilingual |
| **Gemini 3 Pro Image** | Google Vertex | $0.03-$0.24 | ~92% | 4K support, spatial reasoning | High-res assets, print quality |
| **Seedream 4.5** | ByteDance | $0.03 | ~95% | Native 2K, aesthetic quality | Landing pages, social media |

### Turbo/Cost-Optimized Models (Speed-Focused)

| Model | Provider | Cost/Image | Latency | Steps | Strength | Best For |
|--------|-----------|-------------|---------|-----------|-----------|---|
| **Z-Image Turbo** | Alibaba/Tongyi | **$0.0015** | **<1s** | 1-2 | Sub-second dev, UI placeholders |
| **FLUX.1 Schnell** | Black Forest Labs | **$0.0015** | 2-3s | 4 | Speed/quality balance, text rendering |
| **Hyper-SDXL** | Community | **$0.0010** | <1.5s | 1-2 | UI mockups, rapid previews |
| **SDXL Lightning** | ByteDance | **$0.0020** | 1-3s | 1-4 | Progressive distillation, speed |
| **SDXL Turbo** | Stability AI | **$0.0008** | <1s | 1 | Fastest 1-step, previews |
| **FLUX.2 [schnell]** | Black Forest Labs | **$0.003** | 2-4s | 1-4 | High-quality fast generation |

### Text-Specialized Models

| Model | Text Accuracy | Cost | Strength | API Availability | Best For |
|--------|-------------|---------|-----------|----------------|-----------|
| **Ideogram V3** | **98%** | $0.05-$0.10 | Ideogram API, Replicate | Posters, ads, typography |
| **Flux.2 [flex]** | ~96% | $0.04 | Replicate, fal.ai | Banners, headers, text-on-image |
| **Recraft V3** | ~92% | $0.04 | Recraft API | SVG icons, logos, scalable UI |
| **Ovis-Image (7B)** | ~90% | $0.01 | Hugging Face | Labels, signs, UI elements |
| **Qwen-Image-2512** | ~94% | $0.005 | Hugging Face | Multi-line text, posters |

---

## 2. API Provider Comparison

### Foundational API Providers (Developer Focus)

| Provider | Pricing Model | Key Models | Cost (Lowest) | Speed | Pros | Cons |
|-----------|--------------|-------------|-----------------|--------|-------|-------|
| **fal.ai** | Megapixel-based | Flux 2 Turbo, Qwen-Image, Kling | $0.008/MP | **Fastest inference** (<1s), low latency | Limited model variety |
| **Replicate** | Compute-per-second | Flux, SD3.5, community LoRAs | $0.0025-$0.04/image | Largest model marketplace, custom fine-tunes | Cost varies by compute time |
| **Together AI** | Flat per-image | FLUX.1 Schnell, SDXL | $0.001-$0.015/image | Predictable pricing, open models | Smaller model catalog |
| **OpenAI** | Token-based | GPT-Image-1.5, DALL-E 3 | $0.035-$0.133/image | Unified multimodal API, high quality | Expensive, rate limits |
| **Google Vertex AI** | Per-image | Imagen 4, Veo 3 | $0.03-$0.24/image | Enterprise-grade, 4K support | Complex setup, higher cost |
| **SiliconFlow** | Per-image | FLUX.1 Schnell, Z-Image Turbo | **$0.0015/image** | Cheapest, fast | Newer platform, less features |
| **Synexa AI** | Per-image | FLUX.1 Schnell | $0.0015/image | Fast H100 clusters | Limited to fast models |
| **Segmind** | Per-image | Fast Flux Schnell | $0.0026/image | Optimized variants | Niche catalog |

### Subscription-Based Services

| Subscription | Monthly Cost | Daily/Image Limit | Includes API? | Per-Image Cost (Effective) | Best For |
|--------------|----------------|------------------|----------------|---------------------------|-----------|
| **Google AI Pro** | $16.67 (annual) | 100/day | No (UI only) | N/A | Workspace integration, prototyping |
| **ChatGPT Plus** | $20.00 | ~40-50 per 3h window | No | ~$0.015 | Prompt engineering, rapid iteration |
| **Leonardo.ai Artisan** | $30.00 | 25,000 tokens | **Yes** | **$0.0012** | **Best dev value**, API + unlimited UI |
| **Midjourney Pro** | $60.00 | 30 hours fast | No (3rd party) | ~$0.006 | Highest aesthetic quality |
| **Adobe Firefly Std** | $9.99 | 2,000 credits | Yes | ~$0.005 | Commercial indemnified, enterprise-safe |
| **Stability Pro** | $20.00 | Unlimited (license only) | No | N/A | Self-hosting open models |

---

## 3. Benchmark Analysis

### Speed Benchmarks (Generation Time)

| Tier | Model | Latency | Use Case |
|-------|--------|-----------|-----------|
| **Sub-Second** | Z-Image Turbo, SDXL Turbo | <1s | Real-time previews, UI mockups |
| **Ultra-Fast** | FLUX.1 Schnell, Hyper-SDXL | 1-3s | Development workflows, rapid iteration |
| **Fast** | FLUX.2 [schnell], SDXL Lightning | 2-4s | Production assets, marketing materials |
| **Standard** | GPT Image 1.5, FLUX.2 [max] | 5-15s | High-fidelity, complex scenes |
| **Slow** | DALL-E 3, Ideogram V3 | 10-20s | Typography, poster design |

### Quality Rankings (LM Arena / Artificial Analysis Jan 2026)

| Rank | Model | Elo Score | Specialization |
|-------|--------|-----------|---------------|
| **1** | Gemini 3 Pro Vision | 1274 | Spatial reasoning, 4K photorealism |
| **2** | GPT-5.1 / GPT-image-1 | 1239 | Prompt adherence, text rendering |
| **3** | Seedream 4.0 | 1221 | Conversational editing consistency |
| **4** | Flux .1 Kontext [Max] | 1210 | Texture detail, open weights |
| **5** | Nano Banana Pro | 1198 | Fast UI/UX mockups |

### Cost Efficiency (Images Per Dollar)

| Cost Tier | Images Per $1 | Models |
|------------|---------------|---------|
| **< $0.001** | 1000+ | SDXL Turbo, Hyper-SDXL |
| **$0.001-$0.003** | 333-666 | Z-Image Turbo, FLUX.1 Schnell, FLUX.2 [schnell] |
| **$0.003-$0.01** | 100-333 | Together AI Flux, Qwen-Image |
| **$0.01-$0.05** | 20-100 | FLUX.2 [max], GPT Image Mini, Recraft |
| **$0.05+** | <20 | Ideogram V3, GPT Image High, Nano Banana Pro |

---

## 4. Provider Deep Dives

### fal.ai - The Infrastructure King
**Strengths:**
- Lowest latency in industry (<1s for some models)
- Megapixel-based pricing is predictable
- Excellent Python SDK and documentation

**Best Models:**
- Flux 2 Turbo: $0.008/MP
- Qwen-Image: $0.02/MP (text specialist)
- Kling AI Video: $0.10-$0.50 per 5s clip

**Pricing:**
- GPU Hourly: H100 $1.89/hr, H200 $2.10/hr
- Output-based: $0.008/MP for Flux 2 Turbo

**API Docs:** https://fal.ai/docs

### Replicate - The Open-Source Gateway
**Strengths:**
- Largest marketplace of models (thousands)
- Easy to deploy custom LoRAs and fine-tunes
- Community models and checkpoints

**Best Models:**
- black-forest-labs/flux-1.1-pro: $0.04/image
- black-forest-labs/flux-dev: $0.025/image
- black-forest-labs/flux-schnell: $3.00/1000 images

**Pricing:**
- Compute-per-second: $0.0002/s (CPU) to $0.003/s (A100/H100)
- Average FLUX generation: 3-5s cost per image

**API Docs:** https://replicate.com/docs

### Together AI - Low-Cost Inference
**Strengths:**
- Predictable flat pricing
- Access to latest open models
- Good for high-volume workflows

**Best Models:**
- FLUX.1 [schnell]: $0.001/image
- SDXL: $0.006/image

**Pricing:**
- Serverless inference: Per megapixel or flat per-image
- Dedicated endpoints: Custom pricing

**API Docs:** https://docs.together.ai

### OpenAI - Multimodal Standard
**Strengths:**
- Unified multimodal API (text + image + code)
- Best prompt adherence
- Surgical editing capabilities

**Best Models:**
- GPT Image 1.5 Mini: $0.005/image (standard), $0.052/image (HD)
- GPT Image 1.5 High: $0.04-$0.15/image
- DALL-E 3: $0.040/image (standard), $0.080-$0.120/image (HD)

**Pricing:**
- Token-based: Image input $8/1M tokens, Image output $32/1M tokens
- Rate limits: 15-50 images/min (Tier 1), up to 7500/min (Enterprise)

**API Docs:** https://platform.openai.com/docs/

### Google Vertex AI - Enterprise Grade
**Strengths:**
- 4K native support
- Grounding with Google Search
- Workspace integration

**Best Models:**
- Imagen 4: $0.03/image (Fast), $0.134/image (Ultra/4K)
- Gemini 2.5 Flash: $0.039/image
- Veo 3 Video: ~$0.60 per 5s clip

**Pricing:**
- Free tier: 100-180 credits/month (personal accounts)
- Vertex AI: Pay-per-image with enterprise SLAs

**API Docs:** https://cloud.google.com/vertex-ai/generative-ai/pricing

### SiliconFlow - The Cost Leader
**Strengths:**
- Lowest per-image pricing
- Fast H100 clusters
- Focus on distilled/turbo models

**Best Models:**
- FLUX.1 Kontext [dev]: $0.015/image
- FLUX.1 [schnell]: $0.0015/image
- Z-Image Turbo: $0.0015/image

**Pricing:**
- Cheapest in market: $0.0015/image for FLUX.1 Schnell
- ~2-3x cheaper than larger models

**Website:** https://www.siliconflow.com

---

**Cloudflare Workers AI Deep Dive:** See `CLOUDFLARE_DEEP_DIVE.md` for comprehensive analysis including daily capacity calculations, cost efficiency, and free tier optimization for development workflows.

## 5. Existing Image Skills for Agents

### Implementation Patterns

Modern agent skills follow the **Script-Wrapper pattern**:

```
SKILL.md (instructions)
├── scripts/ (API handlers)
│   └── generate_image.py (Python script)
├── references/ (documentation)
└── config.json (provider settings)
```

### Known Skills and Patterns

1. **Wiro Image Fill Skill**
   - Purpose: Replace `<img>` tags and placeholder.png with real assets
   - Pattern: Generate → Save to `public/generated/` → Create `image-map.json`
   - Provider: Wiro.ai / Flux

2. **Nano Banana Pro Skill**
   - Purpose: Multi-turn editing with Gemini 3 Pro
   - Pattern: Iterative conversation with image grounding
   - Key feature: Maintains consistency across edits

3. **Multi-Provider Skills (e.g., cyperx84/image-gen-skills)**
   - Purpose: Route between providers based on use case
   - Providers: Google Pro (Gemini), Replicate (FLUX), Together (SDXL)
   - Logic: Speed vs. quality toggle

4. **Markdown Helper Skills**
   - Purpose: Generate documentation diagrams
   - Pattern: Mermaid.js for flowcharts, SVG for technical diagrams
   - Differentiation: Separate logic for diagrams vs. artistic images

### Best Practices for Image Skills

1. **Support Resolution Scaling**: Offer 1K, 2K, 4K options
2. **Handle Vault/Workspace Storage**: Auto-save to `./assets/` or `./attachments/`
3. **Implement Prompt Refinement**: "Thinking" phase to expand simple prompts
4. **Manage Mapping**: JSON registry of generated images to prevent redundant calls
5. **Differentiate Intent**: Separate logic for diagrams (Mermaid/SVG) vs. visuals (DALL-E/FLUX)

---

## 6. Recommendations by Use Case

### Use Case 1: UI/UX Placeholders & Dev Workflows
**Recommended:** Z-Image Turbo or FLUX.1 Schnell
**Provider:** SiliconFlow or fal.ai
**Cost:** $0.0015-$0.003/image
**Speed:** <3s
**Why:** Sub-second generation, excellent text rendering, cheap for high-volume iterations

### Use Case 2: Landing Page Headers & Hero Images
**Recommended:** FLUX.2 Pro or Seedream 4.5
**Provider:** Replicate or fal.ai
**Cost:** $0.03-$0.04/image
**Speed:** 2-4s
**Why:** High fidelity, 2K native support, excellent composition

### Use Case 3: Social Media Graphics & Posters
**Recommended:** Ideogram V3
**Provider:** Ideogram API or Replicate
**Cost:** $0.05-$0.10/image
**Speed:** 10-15s
**Why:** Best typography accuracy, understands poster layout logic

### Use Case 4: Documentation Images & Diagrams
**Recommended:** Recraft V3 (for icons/SVG) + GPT Image Mini
**Provider:** Recraft API or OpenAI
**Cost:** $0.005-$0.04/image
**Speed:** 3-5s
**Why:** Native SVG for scalable icons, good text for annotations

### Use Case 5: Brand Mockups & Product Shots
**Recommended:** Nano Banana Pro or GPT Image 1.5
**Provider:** Google AI Studio or OpenAI API
**Cost:** $0.04-$0.08/image
**Speed:** 5-10s
**Why:** High realism, grounding search for accurate branding

### Use Case 6: High-Volume Production
**Recommended:** FLUX.1 Schnell via Together AI or SiliconFlow
**Provider:** Together AI or SiliconFlow
**Cost:** $0.0015/image
**Speed:** 2-3s
**Why:** Best cost-performance ratio at scale

### Use Case 7: Enterprise Commercial Use
**Recommended:** Adobe Firefly or Stability Pro
**Provider:** Adobe or Stability AI
**Cost:** $0.005-$0.05/image + $9.99-$20/month
**Speed:** 3-8s
**Why:** Legal indemnification, enterprise-safe licensing

---

## 7. Subscription Value Analysis

### For Frequent Developers (Daily Use)

| Subscription | Monthly Cost | Daily Limit | Effective Cost | Value |
|--------------|----------------|---------------|----------------|--------|
| **Leonardo.ai Artisan** | $30.00 | 25,000 tokens | **$0.0012/image** | ⭐⭐⭐⭐⭐⭐ Best Value |
| **Google AI Pro** | $16.67 | 100 images | N/A (UI only) | ⭐⭐⭐⭐ Good for prototyping |
| **ChatGPT Plus** | $20.00 | ~40-50/3h | **$0.015/image** | ⭐⭐⭐⭐ Good for prompt engineering |
| **Adobe Firefly** | $9.99 | 2,000 credits | **$0.005/image** | ⭐⭐⭐⭐⭐⭐ Enterprise-safe |

**Winner:** Leonardo.ai Artisan for developers - includes API access plus unlimited UI generations at the lowest effective per-image cost.

### For Production APIs (Pay-As-You-Go)

**Rankings by cost:**
1. **SiliconFlow:** $0.0015/image (FLUX.1 Schnell, Z-Image Turbo)
2. **Together AI:** $0.001/image (FLUX.1 Schnell)
3. **Synexa AI:** $0.0015/image (FLUX.1 Schnell)
4. **Segmind:** $0.0026/image (Fast Flux Schnell)
5. **fal.ai:** $0.008/MP (~$0.016/image for 1024x1024)
6. **Replicate:** $0.0025-$0.04/image (varies by model)
7. **OpenAI:** $0.035-$0.133/image (GPT Image 1.5)
8. **Google Vertex:** $0.03-$0.24/image (Imagen 4)

**Winner:** SiliconFlow or Together AI for cheapest production API access.

---

## 8. Top Model Recommendations for AI Dev Atelier Skill

### Primary Recommendation: FLUX.1 Schnell
**Provider:** Together AI or SiliconFlow
**Cost:** $0.0015/image
**Speed:** 2-3s
**Strengths:**
- State-of-the-art prompt adherence
- Excellent text rendering
- Fast generation time
- Open-source weights available
- Best cost-performance ratio

**Best For:** General development workflows, UI mockups, rapid prototyping

### Secondary Recommendation: Z-Image Turbo
**Provider:** fal.ai or SiliconFlow
**Cost:** $0.0015/image
**Speed:** <1s
**Strengths:**
- Sub-second latency
- Bilingual text support (Chinese/English)
- 6B parameters (lightweight)
- Apache 2.0 license
- Good quality for placeholders

**Best For:** Real-time previews, high-volume batch jobs

### Text-Rendering Recommendation: Ideogram V3
**Provider:** Ideogram API or Replicate
**Cost:** $0.05-$0.10/image
**Speed:** 10-15s
**Strengths:**
- 98% text accuracy
- Typography specialist
- Understands poster layout
- Multi-line text stability

**Best For:** Social media graphics, posters, marketing materials with heavy text

### SVG/Vector Recommendation: Recraft V3
**Provider:** Recraft API
**Cost:** $0.04/image
**Speed:** 3-5s
**Strengths:**
- Native high-quality SVG export
- Logo generation
- Scalable UI elements
- Vector output

**Best For:** Icons, logotypes, scalable illustrations for documentation

### Production-Quality Recommendation: GPT Image 1.5
**Provider:** OpenAI API
**Cost:** $0.035-$0.05/image
**Speed:** 5-10s
**Strengths:**
- 4x faster than DALL-E 3
- Surgical precision editing
- Unified multimodal reasoning
- High prompt adherence

**Best For:** Complex scenes, high-context work, production assets

---

## 9. Implementation Considerations

### Multi-Provider Strategy
Implement fallback chain:
1. **Fast/Cheap:** Z-Image Turbo or FLUX.1 Schnell ($0.0015)
2. **Standard Quality:** FLUX.2 Pro or Seedream ($0.03-$0.04)
3. **Text-Specialized:** Ideogram V3 ($0.05-$0.10)
4. **Premium:** GPT Image 1.5 or Nano Banana Pro ($0.04-$0.08)

### Rate Limit Management
- **OpenAI:** 15-50 images/min (Tier 1), aggressive load shedding
- **Google Vertex:** 250 RPD (Tier 1), custom for enterprise
- **Replicate:** 600 RPM (highest documented limits)
- **fal.ai:** No strict RPM, GPU-second based
- **Together AI:** 1000-5000 RPD (Tier 2)

### Local Generation Options
**For developers with RTX 3090/4090:**
- **RTX 4090 + ComfyUI + Hyper-SD:** 0.6s-0.9s per 1024x1024
- **FLUX.1 Schnell GGUF (Q4_0):** 2.5s on 8GB-12GB VRAM
- **Self-hosting cost:** ~$0.0008/image (H100 @ $2/hr, 2400 images/hr)

### Free Tiers
1. **Google Gemini API:** 100-180 free credits/month
2. **OpenAI:** $5.00 starting credits (new accounts)
3. **Recraft.ai:** 30 daily credits (reset every 24h)
4. **Runware:** Free test credits on signup
5. **Cloudflare Workers AI:** 10,000 neurons/day (~100-200 free images)

---

## 10. Source Links & References

### Official Documentation
- **OpenAI:** https://platform.openai.com/docs/
- **Google Vertex AI:** https://cloud.google.com/vertex-ai/generative-ai/pricing
- **fal.ai:** https://fal.ai/docs
- **Replicate:** https://replicate.com/docs
- **Together AI:** https://docs.together.ai
- **Black Forest Labs:** https://bfl.ai
- **Z.AI:** https://docs.z.ai/guides/image/glm-image
- **Ideogram:** https://ideogram.ai/docs

### Benchmark & Comparison Sites
- **LM Arena Vision Leaderboard:** https://lmarena.ai/leaderboard/vision
- **Artificial Analysis Intelligence Index v4.0:** https://felloai.com/best-ai-of-january-2026/
- **AI Pricing Comparison Calculator:** https://www.aipricingcomparison.com/text-to-image-api-pricing-calculator
- **Cursor IDE API Comparison:** https://www.cursor-ide.com/blog/image-generation-api-comparison-2025

### Cost Analysis & Pricing
- **SiliconFlow Cheapest Models:** https://www.siliconflow.com/articles/en/the-cheapest-image-gen-models
- **Runware Pricing:** https://runware.ai/pricing
- **Fal.ai Pricing:** https://fal.ai/pricing
- **Together AI Pricing:** https://www.together.ai/pricing
- **CostGoat OpenAI Guide:** https://costgoat.com/pricing/openai-images
- **Segmind Fast Flux:** https://www.segmind.com/models/fast-flux-schnell/pricing

### Skills & Implementation Examples
- **Wiro Image Fill:** https://github.com/AndacGuven/wiro-image-fill-skill
- **Nano Banana Pro Skill:** https://github.com/hoodini/ai-agents-skills
- **Multi-Provider Skills:** https://github.com/cyperx84/image-gen-skills
- **Markdown Helper:** https://github.com/Interstellar-code/markdown-helper

### Additional Reading
- **Image Generation APIs Comparison 2025:** https://tech.growthx.ai/posts/image-generation-apis-comparison-2025-developer-guide
- **Complete Guide to AI Image Generation APIs in 2026:** https://wavespeed.ai/blog/posts/complete-guide-ai-image-apis-2026
- **Replicate vs Together AI Guide:** https://medium.com/@whyamit101/replicate-vs-together-ai-a-practical-guide-c73bf0600420
- **Cheapest Gemini Image API:** https://fastgptplus.com/en/posts/cheapest-gemini-image-api
- **Best Open-Source Image Models 2025:** https://medium.com/budgetpixel-ai/best-open-source-image-models-right-now-hunyuan-image-3-vs-qwen-image-vs-z-image-turbo-6da568b563c2
- **Fastest AI Image Generation Models 2025:** https://blog.segmind.com/best-ai-image-generation-models-guide/
- **Top 10 AI Image Generators:** https://alphacorp.ai/top-10-ai-image-generators-november-2025/
- **Pruna AI Image Models:** https://supermaker.ai/blog/pruna-ai-image-models-fast-efficient-production-ready-image-generation-editing/

---

## 11. Quick Reference Tables

### Decision Matrix for Development Workflows

| Priority | Model | Provider | Cost | Speed | Quality | Text |
|-----------|--------|-----------|---------|----------|-------|
| **Cost** | FLUX.1 Schnell | Together AI | $0.001 | 2-3s | ⭐⭐⭐⭐⭐ |
| **Speed** | Z-Image Turbo | SiliconFlow | $0.0015 | <1s | ⭐⭐⭐⭐ |
| **Quality** | FLUX.2 [max] | Replicate | $0.04 | 4s | ⭐⭐⭐⭐⭐⭐ |
| **Text** | Ideogram V3 | Ideogram | $0.05 | 15s | ⭐⭐⭐⭐⭐⭐ |
| **Overall** | FLUX.1 Schnell | Together AI | $0.0015 | 2-3s | ⭐⭐⭐⭐⭐ |

### Provider Selection Guide

| Need | Recommended Provider | Why |
|-------|------------------|------|
| **Cheapest API** | SiliconFlow or Together AI | $0.0015/image, open models |
| **Fastest API** | fal.ai | <1s latency, GPU-second pricing |
| **Largest Catalog** | Replicate | Thousands of models + community LoRAs |
| **Best UI/UX** | Leonardo.ai Artisan | API + unlimited generations, $0.0012/image effective |
| **Enterprise** | Google Vertex AI | 4K support, SLAs, GCP integration |
| **Indemnified** | Adobe Firefly | Legal protection, enterprise licensing |

---

## 12. Final Recommendations for AI Dev Atelier Skill

### Core Requirements for the Image Generation Skill

1. **Multi-Provider Support**
   - Primary: FLUX.1 Schnell (Together AI/SiliconFlow) for cost/speed
   - Fallback: FLUX.2 Pro (Replicate/fal.ai) for quality
   - Text-Specialized: Ideogram V3 for typography-heavy tasks
   - SVG: Recraft V3 for icons and scalable graphics

2. **Intelligent Routing Logic**
   ```
   If text-heavy → Ideogram V3
   If needs SVG → Recraft V3
   If priority cost → FLUX.1 Schnell
   If priority speed → Z-Image Turbo
   If priority quality → FLUX.2 Pro or GPT Image 1.5
   ```

3. **Cost Optimization**
   - Default to $0.0015/image tier (FLUX.1 Schnell, Z-Image Turbo)
   - Offer quality tiers: draft ($0.0015), standard ($0.02), premium ($0.04+)
   - Cache generated images to prevent redundant API calls

4. **Resolution Support**
   - 1024x1024 (standard): Base tier
   - 1536x1536 (HD): Standard tier
   - 2048x2048 (2K): Premium tier
   - 4096x4096 (4K): Ultra tier (select models)

5. **File Management**
   - Save to `.ada/images/` or `./assets/generated/`
   - Generate Markdown-ready syntax: `![alt text](./path/to/image.png)`
   - Create image mapping JSON for reference

6. **Prompt Enhancement**
   - "Thinking" phase to expand simple prompts
   - Add modifiers based on use case:
     - Landing page: "4K, cinematic, high fidelity"
     - UI placeholder: "clean, minimal, muted colors"
     - Social media: "vibrant, engaging, viral-worthy"

7. **Rate Limit Handling**
   - Implement exponential backoff for 429 errors
   - Track remaining quota per provider
   - Auto-fallback to alternative provider if rate limited

### Recommended Skill Structure

```
content/skills/image-generation/
├── SKILL.md
├── references/
│   ├── models-comparison.md (this file)
│   ├── api-providers.md
│   └── use-cases.md
└── scripts/
    ├── generate.py (main script)
    ├── providers/
    │   ├── together_ai.py
    │   ├── replicate.py
    │   ├── fal_ai.py
    │   ├── openai.py
    │   ├── google_vertex.py
    │   └── ideogram.py
    └── utils/
        ├── image_cache.py
        ├── prompt_enhancer.py
        └── rate_limiter.py
```

---

## Conclusion

The image generation landscape in 2026 offers excellent options for development workflows:

1. **For cost-effective, fast generation:** FLUX.1 Schnell and Z-Image Turbo at $0.0015/image
2. **For text rendering:** Ideogram V3 remains the gold standard
3. **For production quality:** FLUX.2 Pro and GPT Image 1.5 offer enterprise-grade output
4. **For developer-friendly subscriptions:** Leonardo.ai Artisan provides best value ($0.0012/image effective)

**Recommendation:** Build a multi-provider skill that defaults to FLUX.1 Schnell via Together AI or SiliconFlow for most use cases, with intelligent fallback to specialized providers based on requirements.

---

**Report Generated:** January 15, 2026
**Next Steps:** Design skill architecture, implement provider clients, create SKILL.md with routing logic
