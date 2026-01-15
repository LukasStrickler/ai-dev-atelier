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
| **SDXL Lightning** | ByteDance | $0.0020** | 1-3s | 1-4 | Progressive distillation, speed |
| **SDXL Turbo** | Stability AI | **$0.0008** | <1s | 1 | Fastest 1-step, previews |
| **FLUX.2 [schnell]** | Black Forest Labs | $0.003 | 2-4s | 1-4 | High-quality fast generation |

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
| **Cloudflare Workers AI** | Neuron-based | FLUX.1 Schnell, FLUX.2 Dev | See **Cloudflare Deep Dive** below | **Free tier exception**, integrated billing | Limited model variety |

### Cloudflare Workers AI Deep Dive

**Free Tier Capacity (FLUX.1 Schnell @ 20 steps):**

| Resolution | Tiles | Images/Day (15 steps) | Images/Day (20 steps) |
|------------|-------|-------------|---------------------|---------------------|
| **512×512** | 1 | **1,041** | **694** |
| **1024×1024** | 4 | **260** | **173** |
| **1536×1536** | 9 | **115** | **77** |
| **2048×2048** | 16 | **32** | **16** |

**Key Finding:**
- At **1024×1024** resolution (standard for UI/hero images): **260 images/day** on free tier
- At **1536×1536** resolution (social media): **231 images/day** on free tier

**Step Count Optimization (1024×1024 with FLUX.1 Schnell):**

| Steps | Neurons/Image | Images/Day | Quality |
|-------|---------------|-------------|----------|
| **10 steps** | 192 | **520** | Lower quality (artifacts possible) |
| **15 steps** | 288 | **347** | Good balance for speed/quality |
| **20 steps** | 384 | **260** | Standard quality (recommended) |

**Recommendation:** Use **15-20 steps** for development workflows to maximize speed while maintaining acceptable quality.

**Paid Tier:**
- **Cost:** $0.011 per 1,000 Neurons
- **Per image (1024×1024, 20 steps):** $0.00634
- **Comparison to competitors:**
  - Cloudflare Paid: $0.00634/image (baseline)
  - SiliconFlow: $0.0015/image (4.2x cheaper)
  - Together AI: $0.0010/image (6.3x cheaper)

**Finding:** Cloudflare's free tier is exceptional for development workflows, but paid tier is **2.6x more expensive** than dedicated providers.

**Strategy:** Use Cloudflare free tier for initial prototyping and rapid iteration, then switch to **SiliconFlow** or **Together AI** for production volume.

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

## 4. Specialized Use Case Analysis

### Best Overall Model 2026: **GPT Image 1.5 (OpenAI)**

**Winner Rationale:**
- **Surgical Editing:** Unmatched ability to perform precise, consistent edits while preserving 95%+ of original pixels
- **Conversational Iteration:** Works naturally through multi-turn refinement without "generate and pray"
- **LMArena Leader:** Elo 1264 across diverse benchmarks
- **Speed/Cost Balance:** 4x speedup over 2024 models while remaining cost-competitive
- **Semantic Intelligence:** Best at understanding spatial relationships, complex instructions, and nuanced modifiers

**Cost:** $0.035/image (standard), $0.05/image (high)

**Use Case:**
- General-purpose creative work requiring complex multi-step editing
- High-context scenes with multiple elements and constraints
- Conversational refinement workflows where precision matters more than speed
- When quality is priority over cost

---

### 4.1 Cloudflare Workers AI - Development Workflow Optimization

**Recommendation:** Use Cloudflare Workers AI **free tier** for development workflows

**Why:**
- **Exceptional Free Capacity:** 260 images/day at 1024×1024 resolution (20 steps)
- **Cost:** Completely free for typical dev workflows
- **Model:** FLUX.1 Schnell offers excellent speed/quality balance
- **Integration:** No separate account needed if using Cloudflare Workers

**Daily Capacity Strategy:**

| Use Case | Resolution | Steps | Daily Output (Free) |
|------------|------------|--------|------------------------------|
| **UI Placeholders** | 512×512 | 15 | **1,041** |
| **Rapid Prototyping** | 1024×1024 | 20 | **260** |
| **Hero Images** | 1024×1024 | 25 | **208** |
| **Social Media** | 1536×1536 | 20 | **115** |

**Switching Strategy:**
- Use Cloudflare free tier for prototyping and iteration
- When daily limit reached or need high-volume production: Switch to Together AI ($0.0010/image) or SiliconFlow ($0.0015/image)
- Cloudflare paid tier is 2.6x more expensive - only use for specific needs

---

### 4.2 Whiteboard & Technical Diagrams

**Top Model:** **Google Nano Banana Pro (Gemini 3 Pro Image)**

**Why:**
- **Hand-drawn Aesthetics:** Excels at ballpoint pen, marker-style layouts
- **Spatial Consistency:** Maintains rough sketch structure without adding unnecessary detail
- **Text Understanding:** Strong for annotations, labels, technical terms
- **Fast:** ~10 seconds per generation

**Alternative:** **Recraft V3** (for vector diagrams)

| Diagram Type | Best Model | Cost | Speed | Best For |
|-------------|------------|---------|--------|---------|
| **Whiteboard Sketches** | Nano Banana Pro | Usage-based | ~10s | Brainstorming, rough concepts |
| **Flowcharts & System** | Recraft V3 (Vector) | $0.05/image | 8-12s | Professional diagrams |
| **UI/UX Mockups** | Apriel 1.5 Thinker | $0.005/image | 5-15s | Wireframes, prototypes |

---

### 4.3 Multi-Image Composition & Editing

**Top Models by Capability:**

| Capability | Best Model | Provider | Cost | Key Feature |
|------------|------------|---------|---------|
| **Multi-Image Combine** | Qwen Image Edit 2509 | Alibaba/Fal.ai | $0.0025-$0.05 | 14 reference combination |
| **Conversational Editing** | GPT Image 1.5 Edit | OpenAI | $0.035/image | Multi-turn surgical edits |
| **Object Removal** | Photoroom API | Via Nano Banana Pro | $0.05-$0.25/image | Studio-quality cleanup |
| **Background Replace** | Adobe Firefly | Adobe | $0.10/image | Generative Fill + Expand |
| **Batch Consistency** | Midjourney V7/V8 | Midjourney API | $0.03/image | Character/style lock |

**Use Case Strategy:**
- **Initial Compose:** Use FLUX.1 Schnell or Qwen Image Edit for base generation
- **Refinement:** Use GPT Image 1.5 Edit for surgical changes
- **Object Cleanup:** Use Photoroom or Adobe Firefly for production polish
- **Batch Work:** Use Midjourney V7 for style consistency across many images

---

### 4.4 Logo & Brand Assets

**Top Models:**

| Asset Type | Best Model | Cost | Strength | Best For |
|------------|------------|---------|---------|
| **Vector Logos** | Recraft V3 | $0.05/image | SVG output, infinite scalability | Brand systems |
| **Typography** | Ideogram 3.0 | $0.05-$0.10 | 98% text accuracy | Marketing materials |
| **Product Mockups** | FLUX.1 Pro / Midjourney | $0.04-$0.06 | 3D lighting, shadows | Catalogs |
| **Brand Consistency** | Flux.2 Max | $0.05-image | Subject stability | Large campaigns |

**Recommendation:**
- **Brand Systems:** Use **Recraft V3** for scalable SVG logos and icons with brand style locking
- **Typography:** Use **Ideogram 3.0** for multi-line text and marketing materials
- **Mockups:** Use **FLUX.1 Pro** or **Midjourney V7** for 3D product photography

---

### 4.5 Image Upscaling

**Top Upscaling Approaches:**

| Approach | Best Models | Cost | Quality | Speed |
|------------|------------|---------|----------|--------|---------|
| **GAN-based (Fastest)** | Real-ESRGAN, GFPGAN | Free (local) or $0.001/image | Medium | ~190ms |
| **Transformer (Balanced)** | Swin2SR, HAT | $0.02-$0.05/image | High | 2-4s |
| **Generative (Hallucination)** | Magnific AI, Bloom | $0.05-$0.10/image | Extreme | 5-10s |
| **Unified (Best)** | GPT Image 1.5, NanoBanana 2 | $0.035-$0.05/image | Very High | 3-8s |

**Strategy:**
- **Development:** Use Real-ESRGAN or GFPGAN for free, fast upscaling
- **Quality:** Use Swin2SR or GPT Image 1.5 native upscale for high fidelity
- **Batch Production:** Use Topaz Photo AI or LetsEnhance for volume

---

### 4.6 UI/UX Placeholders & Mockups

**Best Models:**

| Use Case | Primary Model | Secondary | Speed | Cost |
|------------|------------|------------|---------|--------|
| **Placeholders** | FLUX.1 Schnell | Z-Image Turbo | <3s | $0.0015-$0.003 |
| **Wireframes** | Apriel 1.5 Thinker | Recraft V3 | 5-15s | $0.005-$0.04 |
| **Dashboards** | v0.dev / GLM-Image | Claude 4 Sonnet | 8-12s | API pricing |
| **Full Mockups** | FLUX.2 Max | Flux.1 Pro | 4-6s | $0.04-$0.05 |

**Recommendation:**
- **Free Tier Prototyping:** Use Cloudflare FLUX.1 Schnell (260 images/day @ 1024×1024)
- **Structured UI:** Use Apriel 1.5 Thinker for component hierarchy
- **Complex Layouts:** Use v0.dev or Galileo AI for full dashboards
- **Screenshot-to-Design:** Use Claude 4 Sonnet or GPT Image 1.5 for refinement

---

## 5. Existing Image Skills for Agents

### Implementation Patterns

Modern agent skills follow a **Script-Wrapper pattern**:

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
**Cost:** $0.0015/image
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
**Why:** 98% text accuracy, understands poster layout logic

### Use Case 4: Documentation Images & Diagrams
**Recommended (Vector):** Recraft V3
**Recommended (Flowcharts):** GLM-Image or Apriel 1.5 Thinker
**Cost:** $0.04-$0.05/image
**Speed:** 8-12s
**Why:** Native SVG output, clean lines, professional quality

### Use Case 5: Brand Mockups & Product Shots
**Recommended:** FLUX.1 Pro or Midjourney V7
**Provider:** Replicate or Midjourney API
**Cost:** $0.04-$0.06/image
**Speed:** 4-6s
**Why:** Photorealistic 3D lighting, subject stability

### Use Case 6: High-Volume Production
**Recommended:** FLUX.1 Schnell or Z-Image Turbo
**Provider:** Together AI or SiliconFlow
**Cost:** $0.001-$0.0015/image
**Speed:** <3s
**Why:** Best cost-performance ratio, sub-second generation

---

## 7. Final Skill Recommendations

### Core Requirements for Image Generation Skill

1. **Multi-Provider Support**
   - **Primary (Cost/Speed):** FLUX.1 Schnell via Together AI/SiliconFlow ($0.0015/image, <3s)
   - **Quality Fallback:** FLUX.2 Pro via Replicate/fal.ai ($0.04/image, 4-6s)
   - **Text Specialist:** Ideogram V3 via Ideogram API ($0.05/image, 10-15s)
   - **Vector/SVG:** Recraft V3 via Recraft API ($0.04/image, SVG output)
   - **Cloudflare Free Tier:** FLUX.1 Schnell for prototyping (260 images/day @ 1024×1024)

2. **Intelligent Routing Logic**
   ```
   if priority == "cost":
       model = "flux-1-schnell"
       provider = "together_ai" or "siliconflow"
   elif priority == "speed":
       model = "z-image-turbo" or "flux-1-schnell"
       provider = "cloudflare" or "fal.ai"
   elif priority == "quality":
       model = "flux-2-max"
       provider = "replicate" or "fal.ai"
   elif text_heavy:
       model = "ideogram-v3"
       provider = "ideogram"
   elif vector_required:
       model = "recraft-v3"
       provider = "recraft"
   elif upscaling:
       model = "gpt-image-1.5" (native upscale)
       provider = "openai"
   else:
       model = "flux-1-schnell" (default)
       provider = "together_ai" (default)
   ```

3. **Cost Optimization**
   - Default to $0.0015/image tier (FLUX.1 Schnell, Z-Image Turbo)
   - Offer quality tiers: draft ($0.0015), standard ($0.02), premium ($0.04+)
   - Cache generated images to prevent redundant API calls
   - Track daily usage and warn when approaching free tier limits

4. **Resolution Support**
   - **512×512:** UI placeholders, small icons (1 tile)
   - **1024×1024:** Hero images, headers (4 tiles)
   - **1536×1536:** Social media, posters (9 tiles)
   - **2048×2048:** High-res, print quality (16 tiles)

5. **File Management**
   - Save to `.ada/images/` or `./assets/generated/`
   - Generate Markdown-ready syntax: `![alt text](./path/to/image.png)`
   - Create image mapping JSON for reference
   - Support base64 output for direct embedding

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

---

## 8. Source Links & References

### Official Documentation
- **OpenAI:** https://platform.openai.com/docs/
- **Google Vertex AI:** https://cloud.google.com/vertex-ai/generative-ai/pricing
- **fal.ai:** https://fal.ai/docs
- **Replicate:** https://replicate.com/docs
- **Together AI:** https://docs.together.ai
- **Black Forest Labs:** https://bfl.ai
- **Z.AI:** https://docs.z.ai/guides/image/glm-image
- **Ideogram:** https://ideogram.ai/docs
- **Recraft:** https://docs.recraft.ai
- **Cloudflare Workers AI:** https://developers.cloudflare.com/workers-ai/platform/pricing/
- **SiliconFlow:** https://www.siliconflow.com
- **Photoroom:** https://photoroom.com/api

### Benchmark & Comparison Sites
- **LM Arena Vision Leaderboard:** https://lmarena.ai/leaderboard/vision
- **Artificial Analysis Intelligence Index v4.0:** https://felloai.com/best-ai-of-january-2026/
- **AI Pricing Comparison Calculator:** https://www.aipricingcomparison.com/text-to-image-api-pricing-calculator

### Skills & Implementation Examples
- **Wiro Image Fill:** https://github.com/AndacGuven/wiro-image-fill-skill
- **Nano Banana Pro Skill:** https://github.com/hoodini/ai-agents-skills
- **Multi-Provider Skills:** https://github.com/cyperx84/image-gen-skills
- **Markdown Helper:** https://github.com/Interstellar-code/markdown-helper
- **BotWriter Multi-Provider:** https://wordpress.com/plugins/botwriter

### Additional Reading
- **Image Generation APIs Comparison 2025:** https://tech.growthx.ai/posts/image-generation-apis-comparison-2025-developer-guide
- **Complete Guide to AI Image Generation APIs in 2026:** https://wavespeed.ai/blog/posts/complete-guide-ai-image-apis-2026
- **GPT Image 1 Pricing Calculator:** https://langcopilot.com/gpt-image-1-pricing
- **Cheapest Gemini Image API:** https://fastgptplus.com/en/posts/cheapest-gemini-image-api
- **Fastest AI Image Generation Models 2025:** https://blog.segmind.com/best-ai-image-generation-models-guide/
- **Best Open-Source Image Models 2025:** https://medium.com/budgetpixel-ai/best-open-source-image-models-right-now-hunyuan-image-3-vs-qwen-image-vs-z-image-turbo-6da568b563c2
- **Pruna AI Image Models:** https://supermaker.ai/blog/pruna-ai-image-models-fast-efficient-production-ready-image-generation-editing/

---

## Conclusion

The image generation landscape in 2026 offers excellent options for development workflows:

1. **For cost-effective, fast generation:** FLUX.1 Schnell and Z-Image Turbo at $0.0015/image
2. **For text rendering:** Ideogram V3 remains gold standard
3. **For production quality:** FLUX.2 Pro and GPT Image 1.5 offer enterprise-grade output
4. **For developer-friendly subscriptions:** Leonardo.ai Artisan provides best value ($0.0012/image effective)
5. **For rapid development iteration:** Cloudflare Workers AI free tier offers 260 images/day at 1024×1024
6. **For diagrams/vector:** Recraft V3 (SVG) and GLM-Image (knowledge-intensive)
7. **For best overall capability:** GPT Image 1.5 is the single best all-around model

**Recommendation:** Build a multi-provider skill that defaults to FLUX.1 Schnell via Together AI or SiliconFlow for most use cases, with intelligent fallback to specialized providers based on requirements.

---

**Report Generated:** January 15, 2026
**Next Steps:** Design skill architecture, implement provider clients, create SKILL.md with routing logic
