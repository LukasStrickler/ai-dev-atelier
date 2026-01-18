export type Tier = "iterate" | "default" | "premium" | "max";

export const GEN_MODELS: Record<Tier, string> = {
  iterate: "fal-ai/flux-2/flash",
  default: "fal-ai/flux-2/turbo",
  premium: "fal-ai/flux-2-pro",
  max: "fal-ai/flux-2-max",
};

export const GEN_TEXT_MODELS: Record<Tier, string> = {
  iterate: "fal-ai/recraft/v3/text-to-image",
  default: "fal-ai/recraft/v3/text-to-image",
  premium: "fal-ai/ideogram/v2",
  max: "fal-ai/ideogram/v2",
};

export const EDIT_MODELS: Record<Tier, string> = {
  iterate: "fal-ai/flux-2/flash/edit",
  default: "fal-ai/flux-2/turbo/edit",
  premium: "fal-ai/flux-2-pro/edit",
  max: "fal-ai/flux-2-flex/edit",
};

export const UPSCALE_MODELS: Record<Tier, string> = {
  iterate: "fal-ai/seedvr/upscale/image",
  default: "fal-ai/seedvr/upscale/image",
  premium: "fal-ai/clarity-upscaler",
  max: "fal-ai/clarity-upscaler",
};

export const UTIL_MODELS = {
  rembg: "fal-ai/imageutils/rembg",
  vectorize: "fal-ai/recraft/vectorize",
} as const;

export const PRICING = {
  gen: {
    iterate: "FREE (CF)",
    default: "$0.008/MP",
    premium: "$0.03/MP",
    max: "$0.07/MP",
  },
  gen_text: {
    iterate: "$0.04/img",
    default: "$0.04/img",
    premium: "$0.08/img",
    max: "$0.08/img",
  },
  edit: {
    iterate: "$0.005/MP",
    default: "$0.008/MP",
    premium: "$0.03/MP",
    max: "$0.06/MP",
  },
  upscale: {
    iterate: "$0.001/MP",
    default: "$0.001/MP",
    premium: "$0.03/MP",
    max: "$0.03/MP",
  },
  util: {
    rembg: "FREE",
    vectorize: "$0.01/img",
  },
} as const;

export function parseSize(sizeStr: string): { width: number; height: number } {
  const match = sizeStr.match(/^(\d+)x(\d+)$/);
  if (match) {
    return { width: parseInt(match[1], 10), height: parseInt(match[2], 10) };
  }
  return { width: 1024, height: 1024 };
}

export function parseTier(tierStr: string | undefined): Tier {
  if (tierStr === "iterate" || tierStr === "default" || tierStr === "premium" || tierStr === "max") {
    return tierStr;
  }
  return "default";
}
