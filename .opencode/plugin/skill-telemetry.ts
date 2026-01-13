import type { Plugin } from "@opencode-ai/plugin";
import { appendFileSync, existsSync, mkdirSync, readFileSync } from "fs";
import { homedir } from "os";
import { basename, join } from "path";

type ToolArgs = {
  command?: string;
  name?: string;
};

type ToolEvent = {
  tool?: string;
};

type ToolHookOutput = {
  args?: ToolArgs;
};

type SkillEvent = {
  timestamp: string;
  repo: string;
  skill: string;
  event: string;
};

type PluginConfig = {
  plugins?: Record<string, { enabled?: boolean }>;
};

const PLUGIN_NAME = "skill-telemetry";
const LOG_DIR = `${homedir()}/.ada`;
const LOG_PATH = `${LOG_DIR}/skill-events.jsonl`;

const ensureLogDir = () => {
  mkdirSync(LOG_DIR, { recursive: true });
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
  const match = command.match(/\bskills\/([^/\s]+)\/scripts\/([^\s]+\.sh)\b/);
  if (!match) {
    return null;
  }
  return { skill: match[1], script: match[2] };
};

const logEvent = async (
  event: SkillEvent,
  logError?: (message: string, error: unknown) => Promise<void> | void,
) => {
  try {
    ensureLogDir();
    appendFileSync(LOG_PATH, `${JSON.stringify(event)}\n`);
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
      const tool = typeof input.tool === "string" ? input.tool.toLowerCase() : "";
      const args = output.args ?? {};

      if (tool === "skill") {
        const skillName = args.name;
        if (skillName) {
          await logEvent(
            {
              timestamp: new Date().toISOString(),
              repo,
              skill: skillName,
              event: "load",
            },
            reportError,
          );
        }
        return;
      }

      if (tool === "bash") {
        const match = extractSkillScript(args.command);
        if (!match) {
          return;
        }
        await logEvent(
          {
            timestamp: new Date().toISOString(),
            repo,
            skill: match.skill,
            event: match.script,
          },
          reportError,
        );
      }
    },
  };
};
