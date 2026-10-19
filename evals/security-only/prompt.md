---
name: security-only
description: Security sub-skill alone on the planted-defect fixture
tags: [security, regression]
runs: 3
max_turns: 120
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Agent]
---

/codeprobe:codeprobe security ./fixture
