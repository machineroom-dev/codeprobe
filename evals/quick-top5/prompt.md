---
name: quick-top5
description: Quick mode fans out all nine sub-skills and returns a Top 5 Issues table dominated by the planted Criticals
tags: [quick, regression]
runs: 3
max_turns: 200
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Agent]
---

/codeprobe:codeprobe quick ./fixture
