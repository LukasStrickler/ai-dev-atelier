import type { Tier } from "./lib/config";

export type ErrorCode =
  | "CF_AUTH_MISSING"
  | "CF_QUOTA_EXCEEDED"
  | "CF_RATE_LIMIT"
  | "CF_ERROR"
  | "FAL_AUTH_INVALID"
  | "FAL_CREDITS_EXHAUSTED"
  | "FAL_RATE_LIMIT"
  | "FAL_JOB_TIMEOUT"
  | "FAL_NO_IMAGE"
  | "FAL_ERROR";

export interface ProviderResult {
  success: boolean;
  filePath?: string;
  error?: string;
  code?: ErrorCode;
}

export interface GenerationOptions {
  prompt: string;
  tier?: Tier;
  size?: string;
  text?: boolean;
  svg?: boolean;
  n?: number;
  outputDir?: string;
}

export interface EditOptions {
  imagePath: string;
  instruction: string;
  tier?: Tier;
  size?: string;
  references?: string[];
  maskPath?: string;
  outputDir?: string;
}

export interface UpscaleOptions {
  imagePath: string;
  tier?: Tier;
  scale?: number;
  portrait?: boolean;
  outputDir?: string;
}

export interface UtilOptions {
  imagePath: string;
  outputDir?: string;
}
