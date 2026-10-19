---
type: regex
target: last_message
flags: i
pattern: '(?:^|\n)#{1,6} [^\n]*\bCritical\b(?:(?!\n#{1,6} [^\n]*\b(?:Major|Minor|Suggestion)\b)[\s\S]){0,4000}\bSTRIPE_SECRET_KEY\b|\bSTRIPE_SECRET_KEY\b[^\n]{0,200}\bCritical\b'
---

Planted defect #2: hardcoded `STRIPE_SECRET_KEY` reported at Critical. Same Critical-section window as sec-plant-1.
