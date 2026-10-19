---
name: audit-full
description: Full nine-category audit of the planted-defect fixture; the suite's main regression gate
tags: [audit, regression]
runs: 2
max_turns: 200
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Agent]
---

/codeprobe:codeprobe audit ./fixture
