````skill
---
name: ai-memory
description: Persistent AI memory and context management for Laravel projects. Manages a .ai/memory.md file that stores project knowledge, current work progress, and session state. ALWAYS activates at the start of any session or when entering a project. Ensures continuity across sessions, restarts, crashes, and context switches.
---

# AI Memory & Session Continuity

**THIS SKILL IS CRITICAL.** It ensures persistent memory across sessions, preventing knowledge loss from crashes, restarts, or session switches.

## MANDATORY: Session Startup Protocol

**Every time a session starts or you enter a Laravel project, do this FIRST before anything else:**

### 1. Check for Memory File

```
Look for: .ai/memory.md in the project root
```

**If the file EXISTS:**
1. Read it immediately
2. Check the `## Work In Progress` section
3. If there is unfinished work recorded:
   - **Show the user** what was being worked on and where it stopped
   - **Ask:** "I found a record of unfinished work: [task description]. Last status: [status]. Would you like to continue from where we left off, or start something new?"
   - Wait for user's decision before proceeding
4. If no unfinished work, greet and proceed normally

**If the file DOES NOT EXIST:**
1. Create `.ai/` directory and `.ai/memory.md`
2. Initialize with the template below
3. Populate project info by analyzing the project
4. Inform the user: "I created an AI memory file for this project (.ai/memory.md). This stores project context and work progress to maintain continuity across sessions."

### 2. Add `.ai/` to `.gitignore`

Check if `.ai/` is in `.gitignore`. If not, add it:

```
# AI Memory (session-specific, not for version control)
.ai/
```

> **Reason:** The memory file is specific to the development environment and should not be tracked in git.

---

## Memory File Template

```markdown
# AI Project Memory

> Auto-generated and maintained by AI assistant. Do not delete.
> Last updated: [YYYY-MM-DD HH:mm]

---

## Project Identity

- **Project Name:** [name from composer.json or package.json]
- **Laravel Version:** [version]
- **PHP Version:** [version]
- **Project Type:** [API / SPA / Monolith / Package]
- **Database:** [MySQL/PostgreSQL/SQLite]
- **Frontend Stack:** [Blade / Livewire / Inertia+Vue / Inertia+React / None]
- **Auth System:** [Sanctum / Passport / Breeze / Jetstream / Custom / None]
- **Queue Driver:** [redis / database / sqs / sync]
- **Repository URL:** [if available]

## Key Architecture Decisions

<!-- Important decisions that affect how code should be written -->

- [e.g., "Using Action classes instead of Services for single operations"]
- [e.g., "All API responses go through Resources"]
- [e.g., "Multi-tenancy via database-per-tenant"]

## Project Structure Notes

<!-- Non-standard folder structure or organization patterns -->

- [e.g., "Domain-driven structure: app/Domains/Order/, app/Domains/User/"]
- [e.g., "Admin panel uses Filament in app/Filament/"]

## Important Models & Relationships

<!-- Core domain models and their key relationships -->

| Model | Key Relationships | Notes |
|-------|------------------|-------|
| [User] | [hasMany Orders, belongsToMany Roles] | [Central auth model] |

## Key Packages & Integrations

<!-- Non-standard packages that affect how code is written -->

| Package | Purpose | Notes |
|---------|---------|-------|
| [spatie/laravel-permission] | [Role/permission management] | [Use HasRoles trait] |

## Environment & Config Notes

<!-- Important environment-specific information -->

- [e.g., "Uses Redis for cache, sessions, and queues"]
- [e.g., "S3 for file storage in production"]

## Coding Conventions (Project-Specific)

<!-- Any project-specific conventions that override or extend the standard skills -->

- [e.g., "All DTOs extend App\DTOs\BaseData"]
- [e.g., "Use spatie/laravel-data instead of custom DTOs"]

## Known Issues & Technical Debt

<!-- Things to be aware of when working on the codebase -->

- [e.g., "User model has too many responsibilities — needs refactoring"]
- [e.g., "Legacy API v1 routes don't use Resources"]

---

## Work In Progress

<!-- CRITICAL: This section tracks what is currently being worked on -->
<!-- AI MUST update this section when starting, progressing, and completing work -->

### Current Task

- **Status:** [idle | in-progress | paused | blocked]
- **Task:** [none]
- **Description:** [none]
- **Started:** [timestamp]
- **Last Updated:** [timestamp]

### Progress Log

<!-- Chronological log of what was done -->

### Completed Steps
<!-- - [timestamp] Step description — DONE -->

### Remaining Steps
<!-- - [ ] Step description -->

### Notes & Context
<!-- Important context needed to resume this task -->

---

## Session History

<!-- Brief log of past sessions for context -->

| Date | Summary |
|------|---------|
```

---

## MANDATORY: Updating Memory During Work

### When Starting a New Task

Immediately update the `## Work In Progress` section:

```markdown
### Current Task

- **Status:** in-progress
- **Task:** [Brief title, e.g., "Implement user registration API"]
- **Description:** [What is being built/fixed/refactored and why]
- **Started:** [YYYY-MM-DD HH:mm]
- **Last Updated:** [YYYY-MM-DD HH:mm]

### Remaining Steps
- [ ] Create migration for users table
- [ ] Create User model with relationships
- [ ] Create StoreUserRequest form request
- [ ] Create UserService with registration logic
- [ ] Create UserResource for API response
- [ ] Create UserController with store method
- [ ] Add route
- [ ] Write tests
```

### During Work — Update on Key Milestones

After completing each significant step, update memory:

```markdown
### Completed Steps
- [2026-03-01 14:30] Created users migration with all fields — DONE
- [2026-03-01 14:35] Created User model with relationships and casts — DONE

### Remaining Steps
- [ ] Create StoreUserRequest form request
- [ ] Create UserService with registration logic
- ...
```

### When Taking a Break or Session Ends

Update status and add context notes:

```markdown
### Current Task

- **Status:** paused
- **Last Updated:** [now]

### Notes & Context
- UserService is half-done, need to add email verification logic
- Using event-based approach: UserRegistered event → SendVerificationEmail listener
- The migration has been run locally but NOT committed yet
```

### When Task is Complete

```markdown
### Current Task

- **Status:** idle
- **Task:** [none]
- **Description:** [none]

### Session History

| Date | Summary |
|------|---------|
| 2026-03-01 | Implemented user registration API (model, service, controller, tests) |
```

Move completed task to session history and clear the work section.

---

## When to Update Project Identity Section

Update the top sections of memory when you discover:

- A new important package is installed
- A key architecture decision is made
- A non-standard pattern is adopted
- An important model or relationship is created
- A project-specific convention is established
- Technical debt is identified

**Always ask yourself:** "If I started a fresh session right now, would I need to know this?" If yes → write it to memory.

---

## Memory Maintenance Rules

1. **NEVER delete the memory file** — only update it
2. **Always update timestamps** when modifying
3. **Keep entries concise** — this isn't a diary, it's operational context
4. **Work In Progress must always reflect reality** — update it before and after every significant action
5. **Session History** — keep last 20 entries, archive older ones
6. **If memory file gets too large** (>500 lines) — summarize older session history entries
7. **Project Identity** should be updated rarely — only when fundamental things change
8. **Work In Progress** should be updated frequently — every significant step

---

## Recovery Scenarios

### Scenario: Session crashed mid-task
→ On restart, read memory → show "Work In Progress" → ask user to confirm resumption

### Scenario: User returns after days/weeks
→ Read memory → show project summary + last known state → ask what to work on

### Scenario: Different AI model/session picks up
→ Memory file provides full context regardless of which model reads it

### Scenario: Multiple tasks in parallel
→ Use numbered sub-tasks under "Current Task" with individual statuses

````
