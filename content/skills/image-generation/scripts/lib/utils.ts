export type Mode = "gen" | "edit" | "upscale" | "rembg" | "svg";
export type TierLabel = "iterate" | "default" | "premium" | "max" | "free";

export function generateFilename(
  hint: string,
  ext: string = "png",
  mode?: Mode,
  tier?: TierLabel
): string {
  const timestamp = new Date().toISOString().replace(/[-:T.]/g, "").slice(0, 14);
  const safeHint = hint
    .replace(/[^a-zA-Z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 40);

  const parts = [timestamp];
  if (mode) parts.push(mode);
  if (tier) parts.push(tier);
  parts.push(safeHint);

  return `${parts.join("_")}.${ext}`;
}

export function checkEnv(vars: string[]): void {
  const missing = vars.filter((v) => !process.env[v]);
  if (missing.length > 0) {
    console.error(`Error: Missing environment variables: ${missing.join(", ")}`);
    process.exit(1);
  }
}

export async function downloadImage(url: string, filepath: string): Promise<void> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to download image: ${response.statusText}`);
  }
  const buffer = await response.arrayBuffer();
  await Bun.write(filepath, buffer);
  console.log(`✅ Saved to ${filepath}`);
}
