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

export const SkillReminderPlugin: Plugin = async () => {
  return {
    // Hook 1: System Prompt Injection
    // Triggered on every turn to ensure the reminder is present in the system prompt.
    "experimental.chat.system.transform": async (
      input: { sessionID?: string },
      output: { system: string[] }
    ) => {
      // Safety checks
      if (!Array.isArray(output?.system) || output.system.length === 0) return;

      // Idempotency: Don't add if already present
      if (output.system[0].includes("<skill-reminder>")) return;

      // User Requirement: APPEND (+=), do not prepend.
      // We append to system[0] because providers often ignore system[1+].
      output.system[0] += "\n\n" + SKILL_REMINDER;
    },

    // Hook 2: Session Compaction Persistence
    // Triggered when the session history is summarized (compacted).
    // Ensures the reminder survives compaction and remains in the context.
    "experimental.session.compacting": async (
      input: { sessionID?: string },
      output: { context: string[] }
    ) => {
      if (!Array.isArray(output?.context)) return;

      // Idempotency check
      const hasReminder = output.context.some(s => s.includes("<skill-reminder>"));
      if (hasReminder) return;

      // Append to the compacted context list
      output.context.push(SKILL_REMINDER);
    }
  };
};

export default SkillReminderPlugin;
