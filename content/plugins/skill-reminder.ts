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

// Track sessions that have already received the reminder (memory-only, resets on restart)
const remindedSessions = new Set<string>();

/**
 * Skill Reminder Plugin
 *
 * Injects a skill check reminder:
 * 1. Once on the first message of each session (via system.transform with session tracking)
 * 2. Before each compaction (so it survives summarization)
 */
export const SkillReminderPlugin: Plugin = async () => {
  if (!isPluginEnabled()) {
    return {};
  }

  return {
    // Inject into system prompt ONLY on first message of each session
    "experimental.chat.system.transform": async (
      input: { sessionID: string },
      output: { system: string[] },
    ) => {
      if (remindedSessions.has(input.sessionID)) {
        return;
      }
      remindedSessions.add(input.sessionID);
      output.system.push(SKILL_REMINDER);
    },

    // Re-inject before compaction so reminder survives summarization
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
