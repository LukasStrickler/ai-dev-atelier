import type { Plugin } from "@opencode-ai/plugin";
import { existsSync, readFileSync } from "fs";
import { appendFile, mkdir } from "fs/promises";
import { homedir } from "os";
import { basename, join } from "path";

type ToolArgs = {
  command?: string;
  name?: string;
};

type ToolEvent = {
  tool: string;
  sessionID: string;
  callID: string;
};

type ToolHookOutput = {
  args: ToolArgs;
};

type SkillEvent = {
  timestamp: string;
  repo: string;
  skill: string;
  version: string | null;
  event: string;
  sessionID: string;
  arguments?: string;
};

type PluginConfig = {
  plugins?: Record<string, { enabled?: boolean }>;
};

const PLUGIN_NAME = "skill-telemetry";
const LOG_DIR = `${homedir()}/.ada`;
const LOG_PATH = `${LOG_DIR}/skill-events.jsonl`;

// Cached promise to ensure log directory exists (runs once)
let logDirReady: Promise<void> | null = null;

const ensureLogDir = (): Promise<void> => {
  if (!logDirReady) {
    logDirReady = mkdir(LOG_DIR, { recursive: true })
      .then(() => undefined)
      .catch((err) => {
        logDirReady = null;
        throw err;
      });
  }
  return logDirReady;
};

const resolveOpencodeConfigDir = () => {
  const xdgConfig = process.env.XDG_CONFIG_HOME;
  if (xdgConfig) {
    return join(xdgConfig, "opencode");
  }

  const configDir = join(homedir(), ".config", "opencode");
  const legacyDir = join(homedir(), ".opencode");

  if (existsSync(join(configDir, "opencode.json")) || existsSync(configDir)) {
    return configDir;
  }

  if (existsSync(join(legacyDir, "opencode.json")) || existsSync(legacyDir)) {
    return legacyDir;
  }

  return configDir;
};

const isPluginEnabled = () => {
  const configPath = join(resolveOpencodeConfigDir(), "plugin.json");
  if (!existsSync(configPath)) {
    return true;
  }
  try {
    const config = JSON.parse(readFileSync(configPath, "utf-8")) as PluginConfig;
    return config.plugins?.[PLUGIN_NAME]?.enabled !== false;
  } catch {
    return true;
  }
};

const getRepoName = (project?: { name?: string }, worktree?: string, directory?: string) => {
  if (project?.name) {
    return project.name;
  }
  if (worktree) {
    return basename(worktree);
  }
  if (directory) {
    return basename(directory);
  }
  return "unknown";
};

const extractSkillScript = (command?: string) => {
  if (!command) {
    return null;
  }
  const match = command.match(/\b(?:content\/)?skills\/([^/\s]+)\/scripts\/([^\s]+\.sh)(?:\s+(.*))?/);
  if (!match) {
    return null;
  }
  return { skill: match[1], script: match[2], arguments: match[3]?.trim() || null };
};

const skillVersionCache = new Map<string, string | null>();

const extractSkillVersion = (skillName: string): string | null => {
  if (skillVersionCache.has(skillName)) {
    return skillVersionCache.get(skillName) ?? null;
  }

  const skillDir = join(resolveOpencodeConfigDir(), "skills", skillName);
  const skillMdPath = join(skillDir, "SKILL.md");

  if (!existsSync(skillMdPath)) {
    skillVersionCache.set(skillName, null);
    return null;
  }

  try {
    const content = readFileSync(skillMdPath, "utf-8");
    const frontmatterMatch = content.match(/^---\n([\s\S]*?)\n---/);
    if (!frontmatterMatch) {
      skillVersionCache.set(skillName, null);
      return null;
    }

    const frontmatter = frontmatterMatch[1];
    const versionMatch = frontmatter.match(/^\s*version:\s*["']?([^"'\n]+)["']?\s*$/m);
    const version = versionMatch ? versionMatch[1].trim() : null;

    skillVersionCache.set(skillName, version);
    return version;
  } catch {
    skillVersionCache.set(skillName, null);
    return null;
  }
};

const logEvent = async (
  event: SkillEvent,
  logError?: (message: string, error: unknown) => Promise<void> | void,
) => {
  try {
    await ensureLogDir();
    await appendFile(LOG_PATH, `${JSON.stringify(event)}\n`);
  } catch (error) {
    if (logError) {
      await logError("skill telemetry logging failed", error);
      return;
    }
    console.error("skill telemetry logging failed", error);
  }
};

export const SkillTelemetryPlugin: Plugin = async ({ project, directory, worktree, client }) => {
  if (!isPluginEnabled()) {
    return {};
  }

  const repo = getRepoName(project, worktree, directory);
  const reportError = client?.app?.log
    ? async (message: string, error: unknown) => {
        await client.app.log({
          service: PLUGIN_NAME,
          level: "error",
          message,
          extra: { error: String(error) },
        });
      }
    : undefined;

  return {
    "tool.execute.before": async (input: ToolEvent, output: ToolHookOutput) => {
      const tool = input.tool.toLowerCase();
      const args = output.args ?? {};

      if (tool === "skill") {
        const skillName = args.name;
        if (skillName) {
          await logEvent(
            {
              timestamp: new Date().toISOString(),
              repo,
              skill: skillName,
              version: extractSkillVersion(skillName),
              event: "load",
              sessionID: input.sessionID,
            },
            reportError,
          );
        }
        return;
      }

      if (tool === "bash") {
        const command = args.command;
        const match = extractSkillScript(command);

        if (match) {
          await logEvent(
            {
              timestamp: new Date().toISOString(),
              repo,
              skill: match.skill,
              version: extractSkillVersion(match.skill),
              event: match.script,
              sessionID: input.sessionID,
              ...(match.arguments && { arguments: match.arguments }),
            },
            reportError,
          );
        }
      }
    },
  };
};
