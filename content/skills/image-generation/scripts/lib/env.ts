import { existsSync, readFileSync } from "fs";
import { dirname, join } from "path";

/**
 * Find the repository root by traversing up from startDir.
 * Looks for install.sh or .env as markers.
 * @param startDir - Directory to start searching from
 * @returns Repository root path or null if not found
 */
export function findRepoRoot(startDir: string): string | null {
  let dir = startDir;
  for (let i = 0; i < 10; i++) {
    if (existsSync(join(dir, "install.sh")) || existsSync(join(dir, ".env"))) {
      return dir;
    }
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return null;
}

function loadEnvFile(envPath: string): boolean {
  if (!existsSync(envPath)) return false;

  const content = readFileSync(envPath, "utf-8");
  for (const line of content.split("\n")) {
    const match = line.match(/^([^#=]+)=(.*)$/);
    if (match && !process.env[match[1].trim()]) {
      process.env[match[1].trim()] = match[2].trim();
    }
  }
  return true;
}

export function loadEnv(): void {
  const scriptPath = Bun.main || import.meta.path;
  const scriptDir = dirname(scriptPath);

  const repoRoot = findRepoRoot(scriptDir);
  if (repoRoot) {
    loadEnvFile(join(repoRoot, ".env"));
    return;
  }

  loadEnvFile(join(process.cwd(), ".env"));
}
