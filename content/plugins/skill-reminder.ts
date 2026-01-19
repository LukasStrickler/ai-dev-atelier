import type { Plugin } from "@opencode-ai/plugin";
import { existsSync, readFileSync } from "fs";
import { homedir } from "os";
import { join } from "path";

type PluginConfig = {
  plugins?: Record<string, { enabled?: boolean }>;
};

const PLUGIN_NAME = "skill-reminder";

const SKILL_REMINDER = `<skill-reminder>
## MANDATORY: Skill Check Protocol

**BEFORE STARTING ANY WORK**, verify if a skill applies to your task.

### The 1% Rule
If there is even a 1% chance a skill might be relevant, you MUST:
1. Load the skill using the skill tool.
2. Read the instructions completely.
3. Follow the mandated workflow exactly.

### Anti-Rationalization
Do NOT skip this check. The following thoughts are RED FLAGS:
- "This is a simple task" - Simple tasks are where errors hide.
- "I already know how to do this" - Skills contain project-specific requirements you do not know.
- "I will check skills later" - Check BEFORE starting, not after.

**CRITICAL**: Proceeding without loading a relevant skill is a violation of operational protocol.
</skill-reminder>`;

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

// Session state: Map<sessionID, timestamp> with TTL + LRU eviction to prevent memory leaks
const remindedSessions = new Map<string, number>();
const MAX_SESSIONS = 1000;
const TTL_MS = 24 * 60 * 60 * 1000;

const isExpired = (timestamp: number): boolean => Date.now() - timestamp > TTL_MS;

const wasReminded = (sessionID: string): boolean => {
  const timestamp = remindedSessions.get(sessionID);
  if (timestamp === undefined) return false;
  if (isExpired(timestamp)) {
    remindedSessions.delete(sessionID);
    return false;
  }
  return true;
};

const evictOldestIfNeeded = (): void => {
  if (remindedSessions.size < MAX_SESSIONS) return;
  let oldestKey: string | null = null;
  let oldestTime = Infinity;
  for (const [key, time] of remindedSessions) {
    if (time < oldestTime) {
      oldestTime = time;
      oldestKey = key;
    }
  }
  if (oldestKey) remindedSessions.delete(oldestKey);
};

const markReminded = (sessionID: string): void => {
  evictOldestIfNeeded();
  remindedSessions.set(sessionID, Date.now());
};

export const SkillReminderPlugin: Plugin = async () => {
  if (!isPluginEnabled()) {
    return {};
  }

  return {
    "experimental.chat.system.transform": async (
      input: { sessionID: string },
      output: { system: string[] },
    ) => {
      if (wasReminded(input.sessionID)) {
        return;
      }
      markReminded(input.sessionID);
      output.system.push(SKILL_REMINDER);
    },

    "experimental.session.compacting": async (
      _input: { sessionID: string },
      output: { context: string[]; prompt?: string },
    ) => {
      if (!output.prompt) {
        output.context.push(SKILL_REMINDER);
      }
    },
  };
};
