---
type: tool_used
tool: Agent
input_match: '=== VERIFICATION RUBRIC ==='
---

The verification pass ran: the orchestrator spawned the single `quick` verifier. Every verifier prompt carries the `=== VERIFICATION RUBRIC ===` marker block (SKILL.md Section 4B, Verifier prompt composition), and no sub-skill prompt does, so an Agent call with that marker proves the pass ran rather than the orchestrator printing `**Rejected by verification:** 0` without it. The fixture's planted Criticals always rank inside the provisional top 8, so `quick` always has something to verify.
