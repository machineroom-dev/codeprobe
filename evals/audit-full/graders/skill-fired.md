---
type: tool_used
tool: Agent
input_match: '=== SUB-SKILL: codeprobe-[\w-]+ ==='
---

The codeprobe orchestrator ran and dispatched at least one sub-skill. The prompt is the slash command `/codeprobe:codeprobe`, which Claude Code expands inline rather than through the Skill tool, so a `tool_used: Skill` check never sees a call. Instead this checks for an Agent call that carries a `=== SUB-SKILL: codeprobe-<name> ===` marker, which only the orchestrator's Invocation Protocol (SKILL.md Section 4) produces. `audit` dispatches all nine sub-skills, so any one marker proves the orchestrator ran.
