import type { Plugin } from "@opencode-ai/plugin";

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

export const SkillReminderPlugin: Plugin = async () => ({
  "experimental.chat.system.transform": async (
    _input: { sessionID?: string },
    output: { system: string[] }
  ) => {
    if (!Array.isArray(output?.system) || output.system.length === 0) return;
    if (output.system[0].includes("<skill-reminder>")) return;
    output.system[0] += "\n\n" + SKILL_REMINDER;
  }
});

export default SkillReminderPlugin;
