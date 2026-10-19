---
type: tool_used
tool: Agent
input_match: '=== SUB-SKILL: codeprobe-security ==='
---

The codeprobe orchestrator ran and dispatched the security sub-skill. The prompt is the slash command `/codeprobe:codeprobe`, which Claude Code expands inline rather than through the Skill tool, so a `tool_used: Skill` check never sees a call. Instead this checks for the Agent call that carries the `=== SUB-SKILL: codeprobe-security ===` marker, which only the orchestrator's Invocation Protocol (SKILL.md Section 4) produces.
