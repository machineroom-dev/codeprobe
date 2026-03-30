# Codeprobe Token Optimization Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce token consumption by ~50-60% per codeprobe run by eliminating duplicated boilerplate from sub-skills and having the orchestrator pre-load shared context (references, source files, preamble).

**Architecture:** The orchestrator pre-reads source files and reference guides once, creates a shared preamble containing the output contract/modes/constraints, and passes all of this as context in each sub-agent prompt. Sub-skill SKILL.md files are trimmed to contain only their unique detection logic.

**Tech Stack:** Claude Code skills (Markdown SKILL.md files)

---

## File Structure

**New file:**
- `skills/codeprobe/shared-preamble.md` — Contains the output contract, execution modes, READ-ONLY constraint, and summary output format. Read once by orchestrator, injected into each sub-agent prompt.

**Modified files:**
- `skills/codeprobe/SKILL.md` — Orchestrator. Updated Section 4 to pre-load files and inject shared context.
- `skills/codeprobe-security/SKILL.md` — Trimmed (~216 → ~130 lines)
- `skills/codeprobe-error-handling/SKILL.md` — Trimmed (~196 → ~120 lines)
- `skills/codeprobe-solid/SKILL.md` — Trimmed (~185 → ~105 lines)
- `skills/codeprobe-architecture/SKILL.md` — Trimmed (~212 → ~130 lines)
- `skills/codeprobe-patterns/SKILL.md` — Trimmed (~177 → ~100 lines)
- `skills/codeprobe-performance/SKILL.md` — Trimmed (~210 → ~135 lines)
- `skills/codeprobe-code-smells/SKILL.md` — Trimmed (~198 → ~120 lines)
- `skills/codeprobe-testing/SKILL.md` — Trimmed (~194 → ~115 lines)
- `skills/codeprobe-framework/SKILL.md` — Trimmed (~192 → ~115 lines)

---

### Task 1: Create shared preamble file

**Files:**
- Create: `skills/codeprobe/shared-preamble.md`

This file consolidates the sections that are currently duplicated across all 9 sub-skills: the READ-ONLY constraint, output contract, execution modes, and summary output format.

- [ ] **Step 1: Create `skills/codeprobe/shared-preamble.md`**

```markdown
# Shared Sub-Skill Preamble

## READ-ONLY CONSTRAINT

**This sub-skill is strictly read-only. Never modify, write, edit, or delete any file in the user's codebase. Report findings only.**

---

## Output Contract

Every finding MUST include ALL of the following fields:

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | `{PREFIX}-{NNN}` — use the ID prefix specified by your sub-skill |
| `severity` | Yes | One of: `critical`, `major`, `minor`, `suggestion` |
| `location` | Yes | File path + line range (e.g., `src/UserService.php:45-67`) |
| `problem` | Yes | One sentence describing the issue |
| `evidence` | Yes | Concrete proof from the code — quote the relevant lines |
| `suggestion` | Yes | What to do to fix it |
| `fix_prompt` | Yes | A copy-pasteable prompt the user can give to Claude Code to apply the fix. Must reference specific file names, line ranges, method names, and the exact change to make. |
| `refactored_sketch` | No | Optional code snippet showing the improved version |

### Rendered Finding Format

{ID} | {Severity} | `{file}:{lines}`

**Problem:** {problem description}

**Evidence:**
> {quoted code patterns, specific variable names, line references}

**Suggestion:** {what to do to fix it}

**Fix prompt:**
> {copy-pasteable prompt for Claude Code}

**Refactored sketch:** (optional)

---

## Execution Modes

### `full` Mode
Analyze the target path thoroughly. Produce detailed findings for every detected issue with all required fields. Include refactored_sketch for critical and major findings where it adds clarity.

### `scan` Mode
Quick count of issues by severity. Identify the worst offenders. Skip `evidence` and `fix_prompt` fields. Return counts per category, counts by severity, and top 3 worst-offending files.

### `score-only` Mode
Analyze with the **same thoroughness and detection depth as `full` mode** — scan all files, apply all detection rules, identify all violations. The difference is output only: return only the summary severity counts. No individual findings, no evidence, no fix prompts. This ensures health scores match audit scores.

---

## Summary Output

At the end of every execution (regardless of mode), provide a summary:

```json
{
  "skill": "{skill-name}",
  "summary": { "critical": 0, "major": 0, "minor": 0, "suggestion": 0 }
}
```

Replace the zeros with actual counts from the analysis.

---

## Source Files & References

The orchestrator has pre-loaded all source files and reference guides. They are provided below — do NOT use Read, Glob, or Grep to re-read them. Analyze the provided content directly.

If you need to check something not covered in the provided files (e.g., .gitignore existence, specific config files), you may use Read/Grep/Glob for those targeted lookups only.
```

- [ ] **Step 2: Verify the file was created correctly**

Run: `wc -l skills/codeprobe/shared-preamble.md`
Expected: ~65 lines

- [ ] **Step 3: Commit**

```bash
git add skills/codeprobe/shared-preamble.md
git commit -m "feat: add shared preamble for sub-skill token optimization"
```

---

### Task 2: Update orchestrator to pre-load and inject context

**Files:**
- Modify: `skills/codeprobe/SKILL.md` — Section 4 (Sub-Skill Execution)

The orchestrator already detects the stack and loads references (Section 2). The change is to make it:
1. Read the shared preamble once
2. Read ALL source files at the target path once (with a size cap for large codebases)
3. Pass all of this as context in each sub-agent's prompt instead of letting each agent do it independently

- [ ] **Step 1: Replace Section 4 "Invocation Protocol" in `skills/codeprobe/SKILL.md`**

Find the current invocation protocol (lines ~136-147):

```markdown
### Invocation Protocol

For each sub-skill to run:

1. **Invoke the sub-skill by name** (e.g., `codeprobe-solid`, `codeprobe-security`).
2. **Pass the following context** to each sub-skill:
   - `target_path`: The path to review.
   - `detected_stack`: List of detected technology stacks.
   - `references`: Content of all loaded reference files.
   - `config_overrides`: Severity overrides and skip rules from config.
   - `mode`: One of `full`, `scan`, or `score-only` (see below).
3. **Collect findings** returned by each sub-skill in the standard output contract format (Section 5).
```

Replace with:

```markdown
### Pre-Loading Phase (runs once before any sub-skill)

Before invoking any sub-skill, the orchestrator MUST pre-load all shared context:

1. **Read the shared preamble** from `shared-preamble.md` (in this skill's directory). This contains the output contract, execution modes, and constraints shared by all sub-skills.

2. **Read all source files** at the target path:
   - Use Glob to find all source files (`.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.php`, `.vue`, `.sql`, `.css`, `.scss` and config files like `next.config.*`, `package.json`, `composer.json`, `requirements.txt`, `.env.example`).
   - Read each file using Read.
   - **Size cap:** If the codebase has more than 50 source files or total LOC exceeds 10,000 lines, do NOT pre-load all files. Instead, pass only the file listing (paths + line counts) and let sub-agents read files they need. Note this in the agent prompt: "Large codebase — file listing provided, use Read for files you need to inspect."
   - Store all file contents as a map: `{filepath: content}`.

3. **Read all applicable reference files** (already loaded during stack detection in Section 2). Store the content.

### Invocation Protocol

For each sub-skill to run, spawn an Agent with a prompt that includes:

1. **The shared preamble** (from `shared-preamble.md`) — output contract, modes, constraints.
2. **The sub-skill name** to invoke (e.g., `codeprobe-security`).
3. **The mode** — one of `full`, `scan`, or `score-only`.
4. **Pre-loaded source files** — the full content of every source file, formatted as:
   ```
   === FILE: {filepath} ===
   {content}
   === END FILE ===
   ```
5. **Pre-loaded references** — the content of all applicable reference files.
6. **Config overrides** — severity overrides and skip rules from `.codeprobe-config.json`.
7. **Target path** — so the sub-skill knows the project root for any targeted lookups.

The sub-skill's own SKILL.md contains only its domain-specific detection logic. All shared context (output format, modes, source code, references) comes from the orchestrator's prompt.

**Collect findings** returned by each sub-skill in the standard output contract format (Section 5).
```

- [ ] **Step 2: Verify the edit looks correct**

Read the modified section to confirm it flows with the surrounding sections.

- [ ] **Step 3: Commit**

```bash
git add skills/codeprobe/SKILL.md
git commit -m "feat: orchestrator pre-loads source files and shared preamble"
```

---

### Task 3: Trim codeprobe-security SKILL.md

**Files:**
- Modify: `skills/codeprobe-security/SKILL.md`

Remove these duplicated sections:
- "READ-ONLY CONSTRAINT" section (lines 16-20) — now in shared preamble
- "Reference Loading" section (lines 126-135) — orchestrator passes references
- "Output Contract" section (lines 139-184) — now in shared preamble. Keep only a one-line ID prefix note.
- "Execution Modes" section (lines 187-203) — now in shared preamble
- "Summary Output" section (lines 205-216) — now in shared preamble

Keep:
- Frontmatter (lines 1-14)
- Domain Scope (lines 24-37)
- What It Does NOT Flag (lines 41-46)
- Detection Instructions (lines 49-123)
- Fix Prompt Examples (lines 179-183) — move up into Detection Instructions section as a subsection

- [ ] **Step 1: Remove READ-ONLY CONSTRAINT section**

Remove lines 16-20 (the `## READ-ONLY CONSTRAINT` header and its content). This is now in the shared preamble injected by the orchestrator.

- [ ] **Step 2: Remove Reference Loading section**

Remove the entire `## Reference Loading` section (lines 126-135). References are now pre-loaded by the orchestrator and passed as context.

- [ ] **Step 3: Replace Output Contract section with ID prefix note**

Remove the full `## Output Contract` section (lines 139-176) and replace with:

```markdown
---

## ID Prefix & Fix Prompt Examples

All findings use the `SEC-` prefix, numbered sequentially: `SEC-001`, `SEC-002`, etc.

### Fix Prompt Examples

- "In `UserController@update` (line 34), replace `$request->all()` with `$request->only(['name', 'email'])` to prevent mass assignment on the `is_admin` field. Also add `$fillable = ['name', 'email']` to the `User` model if not already present."
- "Wrap the user input at line 55 of `app/Services/SearchService.php` in a parameterized query: change `DB::select(\"SELECT * FROM products WHERE name LIKE '%$search%'\")` to `DB::select('SELECT * FROM products WHERE name LIKE ?', [\"%{$search}%\"])`."
- "In `routes/api.php`, add auth middleware to the `POST /api/orders` route at line 22: change `Route::post('/orders', [OrderController::class, 'store'])` to `Route::post('/orders', [OrderController::class, 'store'])->middleware('auth:sanctum')`."
- "Move the hardcoded API key at line 15 of `config/services.php` to an environment variable: replace `'key' => 'sk-live-abc123...'` with `'key' => env('STRIPE_SECRET_KEY')` and add `STRIPE_SECRET_KEY=` to `.env.example`."
```

- [ ] **Step 4: Remove Execution Modes section**

Remove the entire `## Execution Modes` section (lines 187-203). Now in shared preamble.

- [ ] **Step 5: Remove Summary Output section**

Remove the entire `## Summary Output` section (lines 205-216). Now in shared preamble.

- [ ] **Step 6: Verify trimmed file**

Run: `wc -l skills/codeprobe-security/SKILL.md`
Expected: ~130 lines (down from 216)

- [ ] **Step 7: Commit**

```bash
git add skills/codeprobe-security/SKILL.md
git commit -m "refactor: trim codeprobe-security — remove duplicated boilerplate"
```

---

### Task 4: Trim codeprobe-error-handling SKILL.md

**Files:**
- Modify: `skills/codeprobe-error-handling/SKILL.md`

Same pattern as Task 3. Remove: READ-ONLY CONSTRAINT, Reference Loading, Output Contract (replace with ID prefix + fix examples), Execution Modes, Summary Output.

- [ ] **Step 1: Remove READ-ONLY CONSTRAINT section** (lines 16-20)

- [ ] **Step 2: Remove Reference Loading section** (lines 107-115)

- [ ] **Step 3: Replace Output Contract section with ID prefix note**

Remove lines 119-163. Replace with:

```markdown
---

## ID Prefix & Fix Prompt Examples

All findings use the `ERR-` prefix, numbered sequentially: `ERR-001`, `ERR-002`, etc.

### Fix Prompt Examples

- "Wrap the Stripe API call in `PaymentService@charge` (line 55) in a try/catch for `\Stripe\Exception\ApiErrorException`. Log the error with context (`$orderId`, `$amount`) and throw a domain-specific `PaymentFailedException` with a user-friendly message."
- "Add `DB::transaction()` around the order creation flow in `OrderService@create` (lines 40-65) which currently creates an Order, OrderItems, and Payment record in three separate queries. If any step fails, all should roll back."
- "Replace the empty catch block at `app/Services/NotificationService.php:88` with proper error handling: log the exception with notification context, then decide whether to rethrow (critical notification) or swallow with a metric (non-critical)."
- "Add timeout and retry configuration to the HTTP client call at `ExternalApiClient.php:30`. Use `->timeout(10)->retry(3, 100)` for the Guzzle request to handle transient network failures."
```

- [ ] **Step 4: Remove Execution Modes section** (lines 166-181)

- [ ] **Step 5: Remove Summary Output section** (lines 183-196)

- [ ] **Step 6: Verify and commit**

Run: `wc -l skills/codeprobe-error-handling/SKILL.md`
Expected: ~115 lines (down from 196)

```bash
git add skills/codeprobe-error-handling/SKILL.md
git commit -m "refactor: trim codeprobe-error-handling — remove duplicated boilerplate"
```

---

### Task 5: Trim codeprobe-solid SKILL.md

**Files:**
- Modify: `skills/codeprobe-solid/SKILL.md`

- [ ] **Step 1: Remove READ-ONLY CONSTRAINT section** (lines 16-20)

- [ ] **Step 2: Remove Reference Loading section** (lines 90-99)

- [ ] **Step 3: Replace Output Contract section with ID prefix note**

Remove lines 103-153. Replace with:

```markdown
---

## ID Prefixes & Fix Prompt Examples

- `SRP-` — Single Responsibility Principle violations
- `OCP-` — Open/Closed Principle violations
- `LSP-` — Liskov Substitution Principle violations
- `ISP-` — Interface Segregation Principle violations
- `DIP-` — Dependency Inversion Principle violations

Number findings sequentially within each prefix: `SRP-001`, `SRP-002`, `OCP-001`, etc.

### Fix Prompt Examples

- "Refactor `src/OrderService.php`: extract payment logic (lines 45-78) into a new `PaymentService` class. Inject `PaymentService` via constructor into `OrderService`. Move methods `calculateTotal()`, `applyDiscount()`, and `processPayment()` to the new class."
- "Replace the switch on `$type` in `NotificationSender` (lines 30-65) with a Strategy pattern: create a `NotificationChannel` interface with a `send(Message $message)` method. Create `EmailChannel`, `SmsChannel`, and `PushChannel` implementations. Use a `NotificationChannelFactory` to resolve the correct channel by type."
- "In `UserRepository.php`, replace `new MySqlConnection()` at line 23 with constructor injection: add a `DatabaseConnectionInterface $connection` parameter to the constructor and use it instead of the concrete instantiation."
```

- [ ] **Step 4: Remove Execution Modes section** (lines 156-170)

- [ ] **Step 5: Remove Summary Output section** (lines 172-185)

- [ ] **Step 6: Verify and commit**

Run: `wc -l skills/codeprobe-solid/SKILL.md`
Expected: ~105 lines (down from 185)

```bash
git add skills/codeprobe-solid/SKILL.md
git commit -m "refactor: trim codeprobe-solid — remove duplicated boilerplate"
```

---

### Task 6: Trim codeprobe-architecture SKILL.md

**Files:**
- Modify: `skills/codeprobe-architecture/SKILL.md`

- [ ] **Step 1: Remove READ-ONLY CONSTRAINT section** (lines 16-20)

- [ ] **Step 2: Remove Reference Loading section** (lines 120-130)

Keep the `## Using file_stats.py` section (lines 102-117) — this is unique to architecture.

- [ ] **Step 3: Replace Output Contract section with ID prefix note**

Remove lines 134-179. Replace with:

```markdown
---

## ID Prefix & Fix Prompt Examples

All findings use the `ARCH-` prefix, numbered sequentially: `ARCH-001`, `ARCH-002`, etc.

### Fix Prompt Examples

- "Move the pricing calculation logic from `OrderController@store` (lines 40-75) into a new `PricingService` class under `app/Services/`. The controller should inject `PricingService` and call `$this->pricingService->calculate($order)`. The controller should only handle request parsing, service delegation, and response formatting."
- "Break `UserManager` (850 LOC) into focused services: extract authentication methods (lines 50-200) into `UserAuthService`, profile management (lines 201-450) into `UserProfileService`, and notification methods (lines 451-700) into `UserNotificationService`. `UserManager` becomes a thin facade that delegates to these three services."
- "Resolve the circular dependency between `billing/InvoiceService` and `shipping/ShippingCalculator`: extract the shared interface `ShippingCostProvider` into a `shared/contracts/` directory. Have `ShippingCalculator` implement `ShippingCostProvider`, and have `InvoiceService` depend on the interface instead of the concrete class."
- "Replace the hardcoded URL `http://localhost:3000/api` at line 23 of `src/services/ApiClient.ts` with an environment variable: use `process.env.API_BASE_URL` loaded through the config module. Add `API_BASE_URL=http://localhost:3000/api` to `.env.example`."
- "Create a domain-based directory structure: move `UserController`, `UserService`, `UserRepository`, and `UserPolicy` into a `app/Domains/User/` directory. Repeat for `Order`, `Payment`, and `Notification` domains. Each domain directory should contain its own controllers, services, models, and policies."
```

- [ ] **Step 4: Remove Execution Modes section** (lines 183-197)

- [ ] **Step 5: Remove Summary Output section** (lines 199-212)

- [ ] **Step 6: Verify and commit**

Run: `wc -l skills/codeprobe-architecture/SKILL.md`
Expected: ~130 lines (down from 212)

```bash
git add skills/codeprobe-architecture/SKILL.md
git commit -m "refactor: trim codeprobe-architecture — remove duplicated boilerplate"
```

---

### Task 7: Trim codeprobe-patterns SKILL.md

**Files:**
- Modify: `skills/codeprobe-patterns/SKILL.md`

- [ ] **Step 1: Remove READ-ONLY CONSTRAINT section** (lines 16-20)

- [ ] **Step 2: Remove Reference Loading section** (lines 85-94)

- [ ] **Step 3: Replace Output Contract section with ID prefix note**

Remove lines 98-144. Replace with:

```markdown
---

## ID Prefix & Fix Prompt Examples

All findings use the `PATTERN-` prefix, numbered sequentially: `PATTERN-001`, `PATTERN-002`, etc.

### Fix Prompt Examples

- "Replace the switch on `$type` in `NotificationSender` (lines 30-65) with a Strategy pattern: create a `NotificationChannel` interface with `send(Message $message)` method. Create `EmailChannel`, `SmsChannel`, and `PushChannel` implementations. Use a `NotificationChannelFactory` to resolve the correct channel by type."
- "Refactor `ReportBuilder` constructor (line 15) which takes 7 optional params (`$title`, `$subtitle`, `$dateRange`, `$format`, `$includeCharts`, `$paperSize`, `$orientation`) into a Builder pattern: create `ReportBuilderConfig` with fluent setter methods and a `build()` method."
- "The `AuditLogger` at `app/Services/AuditLogger.php` uses `AuditLogger::getInstance()` (line 5) as a singleton. Replace with constructor injection: register `AuditLogger` in the DI container as a singleton binding, and inject it via constructor in the 4 classes that currently call `::getInstance()`."
- "Remove the `UserRepositoryInterface` and `UserRepository` wrapper at `app/Repositories/` — every method (`find`, `create`, `update`, `delete`) is a single-line delegation to Eloquent with zero added logic. Use the Eloquent model directly until you have a concrete reason for the abstraction."
```

- [ ] **Step 4: Remove Execution Modes section** (lines 148-162)

- [ ] **Step 5: Remove Summary Output section** (lines 164-177)

- [ ] **Step 6: Verify and commit**

Run: `wc -l skills/codeprobe-patterns/SKILL.md`
Expected: ~100 lines (down from 177)

```bash
git add skills/codeprobe-patterns/SKILL.md
git commit -m "refactor: trim codeprobe-patterns — remove duplicated boilerplate"
```

---

### Task 8: Trim codeprobe-performance SKILL.md

**Files:**
- Modify: `skills/codeprobe-performance/SKILL.md`

- [ ] **Step 1: Remove READ-ONLY CONSTRAINT section** (lines 16-20)

- [ ] **Step 2: Remove Reference Loading section** (lines 116-130)

Keep the `### Optional Script Integration` note about `complexity_scorer.py` — move it into the Detection Instructions section or leave as a standalone note after detection tables.

- [ ] **Step 3: Replace Output Contract section with ID prefix note**

Remove lines 133-178. Replace with:

```markdown
---

## ID Prefix & Fix Prompt Examples

All findings use the `PERF-` prefix, numbered sequentially: `PERF-001`, `PERF-002`, etc.

### Fix Prompt Examples

- "In `OrderController@index` (line 22), add `->with('items', 'customer')` to the `Order::query()` call to fix the N+1 problem — currently loading 2 relations lazily inside the Blade loop at `orders/index.blade.php:15`."
- "Replace `Product::all()` at line 30 of `CatalogService.php` with `Product::query()->paginate(25)` or `Product::cursor()` if processing all records. The current query loads all products into memory."
- "In `ReportGenerator@aggregate` (lines 45-60), the nested loop iterating `$orders` inside `$customers` is O(n*m). Build a lookup hashmap before the outer loop: `$ordersByCustomerId = collect($orders)->groupBy('customer_id')`."
- "Replace `import _ from 'lodash'` at line 3 of `src/utils/helpers.ts` with specific imports: `import debounce from 'lodash/debounce'` to reduce bundle size."
```

- [ ] **Step 4: Remove Execution Modes section** (lines 182-195)

- [ ] **Step 5: Remove Summary Output section** (lines 197-210)

- [ ] **Step 6: Verify and commit**

Run: `wc -l skills/codeprobe-performance/SKILL.md`
Expected: ~135 lines (down from 210)

```bash
git add skills/codeprobe-performance/SKILL.md
git commit -m "refactor: trim codeprobe-performance — remove duplicated boilerplate"
```

---

### Task 9: Trim codeprobe-code-smells SKILL.md

**Files:**
- Modify: `skills/codeprobe-code-smells/SKILL.md`

- [ ] **Step 1: Remove READ-ONLY CONSTRAINT section** (lines 16-20)

- [ ] **Step 2: Remove Reference Loading section** (lines 107-116)

- [ ] **Step 3: Replace Output Contract section with ID prefix note**

Remove lines 120-166. Replace with:

```markdown
---

## ID Prefix & Fix Prompt Examples

All findings use the `SMELL-` prefix, numbered sequentially: `SMELL-001`, `SMELL-002`, etc.

### Fix Prompt Examples

- "Extract lines 45-90 of `UserService@register` into a private method `validateAndNormalizeInput()` — the method is 120 LOC doing 3 unrelated things: input validation (lines 45-65), data normalization (lines 66-80), and persistence (lines 81-90). Keep persistence in `register()` and extract the other two concerns."
- "Replace the magic number `86400` at line 55 of `app/Services/CacheService.php` with a named constant `SECONDS_PER_DAY = 86400` defined at the top of the class."
- "Refactor `processOrder(bool $isExpress, bool $requiresSignature, bool $isFragile)` in `OrderProcessor.php` (line 30) to accept a `ShippingOptions` value object instead of 3 boolean parameters. Create a `ShippingOptions` class with named properties."
- "Remove the commented-out code block at lines 88-105 of `PaymentGateway.php` — this is dead code from a previous implementation. If needed later, it can be recovered from version control."
- "In `ReportGenerator.php`, the `generate()` method at line 20 is 95 LOC. Extract the data-fetching logic (lines 25-50) into `fetchReportData()` and the formatting logic (lines 51-85) into `formatReport()`. The `generate()` method should orchestrate these two steps."
```

- [ ] **Step 4: Remove Execution Modes section** (lines 169-183)

- [ ] **Step 5: Remove Summary Output section** (lines 185-198)

- [ ] **Step 6: Verify and commit**

Run: `wc -l skills/codeprobe-code-smells/SKILL.md`
Expected: ~120 lines (down from 198)

```bash
git add skills/codeprobe-code-smells/SKILL.md
git commit -m "refactor: trim codeprobe-code-smells — remove duplicated boilerplate"
```

---

### Task 10: Trim codeprobe-testing SKILL.md

**Files:**
- Modify: `skills/codeprobe-testing/SKILL.md`

- [ ] **Step 1: Remove READ-ONLY CONSTRAINT section** (lines 16-20)

- [ ] **Step 2: Remove Reference Loading section** (lines 103-111)

- [ ] **Step 3: Replace Output Contract section with ID prefix note**

Remove lines 115-162. Replace with:

```markdown
---

## ID Prefix & Fix Prompt Examples

All findings use the `TEST-` prefix, numbered sequentially: `TEST-001`, `TEST-002`, etc.

### Fix Prompt Examples

- "Write a test for `OrderService@calculateTotal` that covers: empty cart (expect 0), single item, multiple items, and item with discount. Use `OrderFactory` for test data. Place in `tests/Unit/Services/OrderServiceTest.php`."
- "The test `test_user_can_login` at `tests/Feature/AuthTest.php:25` has no assertions — it only calls the login endpoint. Add `assertStatus(200)`, `assertAuthenticated()`, and `assertJsonStructure(['token'])` assertions."
- "In `tests/Unit/PaymentServiceTest.php:40`, the mock chain is mocking too deeply. Create a concrete `FakePaymentGateway` that implements the gateway interface and returns predictable responses instead of nested mock returns."
- "Replace the hardcoded user ID `42` in `tests/Feature/OrderTest.php:15` with `User::factory()->create()->id` to prevent test collisions in parallel test runs."
```

- [ ] **Step 4: Remove Execution Modes section** (lines 165-179)

- [ ] **Step 5: Remove Summary Output section** (lines 181-194)

- [ ] **Step 6: Verify and commit**

Run: `wc -l skills/codeprobe-testing/SKILL.md`
Expected: ~115 lines (down from 194)

```bash
git add skills/codeprobe-testing/SKILL.md
git commit -m "refactor: trim codeprobe-testing — remove duplicated boilerplate"
```

---

### Task 11: Trim codeprobe-framework SKILL.md

**Files:**
- Modify: `skills/codeprobe-framework/SKILL.md`

- [ ] **Step 1: Remove READ-ONLY CONSTRAINT section** (lines 16-20)

- [ ] **Step 2: Remove Reference Loading section** (lines 102-111)

- [ ] **Step 3: Replace Output Contract section with ID prefix note**

Remove lines 115-160. Replace with:

```markdown
---

## ID Prefix & Fix Prompt Examples

All findings use the `FWK-` prefix, numbered sequentially: `FWK-001`, `FWK-002`, etc.

### Fix Prompt Examples

- "Move the validation rules from `OrderController@store` (lines 15-30) into a new `StoreOrderRequest` form request class: run `php artisan make:request StoreOrderRequest`, move the validation array, and type-hint `StoreOrderRequest` in the controller method signature."
- "Replace the `env('MAIL_HOST')` call at line 12 of `app/Services/MailService.php` with `config('mail.mailers.smtp.host')`. The `env()` function returns `null` when the config is cached. Move the env lookup to `config/mail.php` where it belongs."
- "The `ProductList` component at `src/components/ProductList.tsx` (220 LOC) should be decomposed: extract `ProductCard` (lines 50-90), `ProductFilters` (lines 100-140), and `ProductPagination` (lines 160-200) into separate components in the same directory."
- "Add missing dependency `userId` to the `useEffect` dependency array at `src/hooks/useProfile.ts:15`. The current empty array `[]` means the effect runs once with the initial `userId` and never refetches when it changes."
```

- [ ] **Step 4: Remove Execution Modes section** (lines 163-177)

- [ ] **Step 5: Remove Summary Output section** (lines 179-192)

- [ ] **Step 6: Verify and commit**

Run: `wc -l skills/codeprobe-framework/SKILL.md`
Expected: ~115 lines (down from 192)

```bash
git add skills/codeprobe-framework/SKILL.md
git commit -m "refactor: trim codeprobe-framework — remove duplicated boilerplate"
```

---

### Task 12: Verify the complete system

- [ ] **Step 1: Check all sub-skill line counts**

```bash
wc -l skills/codeprobe*/SKILL.md
```

Expected total: ~1,550 lines (down from ~2,238 including orchestrator). The 9 sub-skills should total ~1,070 lines (down from ~1,780).

- [ ] **Step 2: Verify no sub-skill still contains "## Output Contract" section**

```bash
grep -l "## Output Contract" skills/codeprobe-*/SKILL.md
```

Expected: no results (0 files matched).

- [ ] **Step 3: Verify no sub-skill still contains "## Execution Modes" section**

```bash
grep -l "## Execution Modes" skills/codeprobe-*/SKILL.md
```

Expected: no results.

- [ ] **Step 4: Verify no sub-skill still contains "## Reference Loading" section**

```bash
grep -l "## Reference Loading" skills/codeprobe-*/SKILL.md
```

Expected: no results.

- [ ] **Step 5: Verify shared-preamble.md exists and is complete**

```bash
cat skills/codeprobe/shared-preamble.md | head -5
```

Expected: starts with `# Shared Sub-Skill Preamble`.

- [ ] **Step 6: Verify orchestrator references shared-preamble.md**

```bash
grep "shared-preamble" skills/codeprobe/SKILL.md
```

Expected: at least one match referencing the file.

- [ ] **Step 7: Final commit**

```bash
git add -A
git commit -m "chore: verify codeprobe token optimization complete"
```

---

## Token Savings Estimate

### Before (per `/codeprobe health` on a 16-file Next.js project)

| Component | Tokens |
|-----------|--------|
| 9 sub-skill SKILL.md loads | ~1,780 lines × ~3 tokens/line = ~5,340 |
| 9× reference loading (each agent reads ~2 refs) | ~544 lines × 9 × ~3 = ~14,688 |
| 9× source file reading (each agent reads ~16 files) | ~1,416 lines × 9 × ~3 = ~38,232 |
| Orchestrator + overhead | ~5,000 |
| **Total** | **~63,260** |

### After

| Component | Tokens |
|-----------|--------|
| 9 sub-skill SKILL.md loads (trimmed) | ~1,070 lines × ~3 = ~3,210 |
| 1× shared preamble (in each agent prompt) | ~65 lines × 9 × ~3 = ~1,755 |
| 1× reference loading (orchestrator only) | ~544 lines × ~3 = ~1,632 |
| 1× source file reading (orchestrator only) | ~1,416 lines × ~3 = ~4,248 |
| Source files passed in agent prompts | ~1,416 lines × 9 × ~3 = ~38,232 |
| Orchestrator + overhead | ~5,000 |
| **Total** | **~54,077** |

**Wait — source files still get duplicated across 9 agent prompts.** The savings from pre-loading is eliminating the 9× Read tool calls and reference file reads, but the content still goes into each agent's context. The real savings are:

1. **Sub-skill SKILL.md trimming**: ~2,130 tokens saved (boilerplate removed)
2. **Reference deduplication**: ~13,056 tokens saved (loaded once vs 9 times via Read tool)
3. **Read tool call overhead eliminated**: ~9 tool calls × 16 files = ~144 Read calls eliminated

The tool call overhead is the hidden cost — each Read call adds prompt/response overhead beyond just the file content. Eliminating ~130 Read tool calls across the 9 agents is significant.

**Realistic estimate: 30-40% total token reduction** from eliminating redundant Read calls and trimming sub-skill files. The remaining cost is inherent to parallel analysis — each agent needs the source code in its context.
