````skill
---
name: laravel-project-docs
description: Project analysis, planning, and technical documentation for Laravel applications. Activates when starting a new project, entering an existing project without documentation, planning features, creating technical specs, or when documentation is missing or outdated. Ensures every project has proper analysis, architecture docs, and implementation plans.
---

# Laravel Project Analysis, Planning & Technical Documentation

## When This Skill Activates

- Entering a Laravel project for the first time
- User asks to analyze, document, or plan anything
- Project is missing `docs/` folder or key documentation
- Starting a new feature or major refactoring
- Onboarding a new developer (or AI session)

---

## MANDATORY: Documentation Check on Project Entry

During the onboarding process (Step 4: Project Analysis), **always check if technical documentation exists:**

```
Look for:
  docs/                          # Main documentation folder
  docs/ARCHITECTURE.md           # Architecture overview
  docs/API.md                    # API documentation
  docs/DATABASE.md               # Database schema docs
  docs/DEPLOYMENT.md             # Deployment guide
  README.md                      # Project README (should exist)
```

### If Documentation is Missing or Incomplete

**Inform the user immediately:**

> "Ovaj projekat nema tehničku dokumentaciju (docs/ folder ne postoji). Preporučujem da kreiramo osnovnu dokumentaciju — ovo će pomoći i meni i svakom budućem developeru da brže razume projekat. Da li želiš da analiziram projekat i generišem dokumentaciju?"

**If the user agrees, perform a full project analysis and generate docs (see sections below).**

---

## Documentation Structure

Every Laravel project should have a `docs/` folder with the following structure:

```
docs/
├── ARCHITECTURE.md          # System architecture & design decisions
├── DATABASE.md              # Database schema, ERD, relationships
├── API.md                   # API endpoints documentation
├── FEATURES.md              # Feature list with status
├── DEPLOYMENT.md            # How to deploy & environment setup
├── DEVELOPMENT.md           # Local setup & development guide
├── CHANGELOG.md             # Version history & changes
└── plans/                   # Feature/task implementation plans
    ├── TEMPLATE.md          # Plan template
    └── [feature-name].md    # Individual feature plans
```

> **Note:** Not every project needs ALL of these. Start with ARCHITECTURE.md and DATABASE.md — these provide the most value. Add others as needed.

---

## 1. Project Analysis Procedure

When analyzing a Laravel project (new or existing), follow this structured approach:

### Phase 1: Technical Inventory

Collect and document the following:

```markdown
## Technical Inventory

### Stack
- **PHP Version:** [from composer.json → require → php]
- **Laravel Version:** [from composer.json → require → laravel/framework]
- **Database:** [from .env or config/database.php → default]
- **Cache/Queue Driver:** [from .env → CACHE_DRIVER, QUEUE_CONNECTION]
- **Frontend:** [Blade / Livewire / Inertia+Vue / Inertia+React / API-only]
- **Auth:** [Sanctum / Passport / Breeze / Jetstream / Fortify / Custom]

### Key Packages
[Read composer.json → require section, list non-Laravel packages with purpose]

### Infrastructure
- **Local Dev:** [Herd / Sail / Docker / Valet / Homestead]
- **Production:** [Forge / Vapor / Custom server / Kubernetes]
- **CI/CD:** [GitHub Actions / GitLab CI / Bitbucket Pipelines / None]
```

### Phase 2: Architecture Analysis

```markdown
## Architecture Pattern

### Application Type
- [ ] Monolith (traditional)
- [ ] Monolith with API (Inertia/Livewire + API for mobile)
- [ ] API-only (SPA backend / mobile backend)
- [ ] Multi-tenant
- [ ] Modular monolith (domain folders)
- [ ] Microservice component

### Code Organization
- [ ] Standard Laravel structure (app/Models, app/Http, etc.)
- [ ] Domain-Driven (app/Domains/Order/, app/Domains/User/)
- [ ] Modular (app/Modules/ or packages/)
- [ ] Custom structure: [describe]

### Design Patterns Used
- [ ] Services (app/Services/)
- [ ] Actions (app/Actions/)
- [ ] DTOs (app/DTOs/ or spatie/laravel-data)
- [ ] Repository Pattern (app/Repositories/)
- [ ] Event-Driven (Events + Listeners)
- [ ] CQRS (Commands/Queries)
- [ ] Observer Pattern (app/Observers/)
- [ ] Strategy Pattern
- [ ] None / mixed / unclear
```

### Phase 3: Database Analysis

```markdown
## Database Schema

### Models Found
[List all models from app/Models/ with their key relationships]

| Model | Table | Key Relationships | Traits Used |
|-------|-------|-------------------|-------------|
| User | users | hasMany Posts, belongsToMany Roles | HasFactory, Notifiable |

### Migration Status
- Total migrations: [count]
- Latest migration: [name and date]
- Pending migrations: [yes/no]

### Key Indexes
[Note any custom indexes, composite keys, or missing indexes that should exist]
```

### Phase 4: API Analysis (if applicable)

```markdown
## API Structure

### Route Groups
[Analyze routes/api.php and list route groups]

| Prefix | Middleware | Controller(s) | Endpoints |
|--------|-----------|---------------|-----------|
| /api/v1/users | auth:sanctum | UserController | CRUD + custom |

### Authentication
- Method: [Sanctum / Passport / JWT / API Key]
- Token type: [Bearer / Cookie / Header]

### API Versioning
- Strategy: [URL prefix / Header / None]
- Current versions: [v1, v2]
```

### Phase 5: Quality Assessment

```markdown
## Code Quality Assessment

### Testing
- Test framework: [Pest / PHPUnit / None]
- Test count: [number]
- Coverage areas: [Models / API / Feature / None]
- Missing test coverage: [areas that need tests]

### Code Style
- Formatter: [Pint / PHP-CS-Fixer / None]
- Static analysis: [PHPStan / Larastan / Psalm / None]
- CI checks: [yes / no]

### Technical Debt
[List identified issues]
- [ ] [Issue description — severity: high/medium/low]

### Security Review
- Mass assignment protection: [guarded / fillable / mixed]
- SQL injection risks: [raw queries found? yes/no]
- XSS protection: [{!! !!} usage found? yes/no]
- CSRF: [proper middleware? yes/no]
- Authorization: [Policies / Gates / inline / none]
```

---

## 2. ARCHITECTURE.md Template

Generate this document after completing the analysis:

```markdown
# [Project Name] — Architecture Documentation

> Generated: [date] | Last updated: [date]

## Overview

[2-3 sentences describing what the application does and who it's for]

## Tech Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | Laravel | x.x |
| PHP | | x.x |
| Database | MySQL/PostgreSQL | x.x |
| Cache | Redis/Memcached | - |
| Queue | Redis/Database | - |
| Frontend | Blade/Livewire/Inertia | x.x |
| Auth | Sanctum/Passport | x.x |

## Architecture Diagram

[Text-based or Mermaid diagram of the system]

## Application Structure

[Describe the folder organization and why]

## Key Design Decisions

| Decision | Rationale | Date |
|----------|-----------|------|
| [e.g., Using Actions over Services] | [Single-purpose, testable] | [date] |
| [e.g., Spatie Data for DTOs] | [Validation + transformation built-in] | [date] |

## Domain Model Overview

[Describe the core business entities and how they relate]

## External Integrations

| Service | Purpose | Package/Method |
|---------|---------|---------------|
| [Stripe] | [Payments] | [laravel/cashier] |

## Authentication & Authorization

[Describe the auth flow and permission system]

## Caching Strategy

[Describe what is cached, how, and cache invalidation approach]

## Queue & Background Jobs

[List key jobs and what they do]

## Error Handling

[Describe the error handling strategy]
```

---

## 3. Feature Planning Procedure

When a user asks to build a new feature or make significant changes, **always create a plan first.**

### When to Create a Plan

- New feature with more than 3 files involved
- Significant refactoring
- API endpoint addition with model/migration/controller/tests
- Integration with external service
- Any change the user explicitly asks to plan

### Feature Plan Template

Create the plan at `docs/plans/[feature-name].md`:

```markdown
# Feature Plan: [Feature Name]

> Status: draft | approved | in-progress | completed
> Created: [date]
> Author: AI Assistant + [user name]

## Summary

[1-2 sentences: what this feature does and why it's needed]

## Requirements

### Functional Requirements
1. [User can...]
2. [System should...]

### Non-Functional Requirements
- Performance: [expected load, response times]
- Security: [auth requirements, data protection]
- Scalability: [considerations]

## Technical Design

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `app/Models/Invoice.php` | Create | Invoice model with relationships |
| `database/migrations/xxxx_create_invoices_table.php` | Create | Database table |
| `app/Http/Controllers/Api/InvoiceController.php` | Create | CRUD endpoints |
| `app/Http/Requests/StoreInvoiceRequest.php` | Create | Validation |
| `app/Http/Resources/InvoiceResource.php` | Create | API response format |
| `app/Services/InvoiceService.php` | Create | Business logic |
| `tests/Feature/InvoiceTest.php` | Create | API tests |

### Database Changes

```sql
-- invoices table structure
id, user_id, number, status (enum), total, due_date, paid_at, timestamps
-- indexes: user_id, status, due_date
```

### API Endpoints (if applicable)

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | /api/invoices | List user invoices | Sanctum |
| POST | /api/invoices | Create invoice | Sanctum |
| GET | /api/invoices/{id} | Show invoice | Sanctum |

### Business Logic

[Describe the key logic, edge cases, and validation rules]

### Events & Side Effects

- `InvoiceCreated` → Send notification email
- `InvoicePaid` → Update accounting system

## Implementation Order

1. [ ] Migration + Model
2. [ ] Form Request (validation)
3. [ ] Service/Action (business logic)
4. [ ] Resource (API response)
5. [ ] Controller + Routes
6. [ ] Tests
7. [ ] Documentation update

## Edge Cases & Considerations

- [What happens if...?]
- [Race condition risk?]
- [Performance with large datasets?]

## Testing Plan

| Test | Type | Description |
|------|------|-------------|
| Can create invoice | Feature | POST /api/invoices with valid data |
| Validates required fields | Feature | POST with missing data → 422 |
| Unauthorized access | Feature | Access without token → 401 |
| Invoice total calculation | Unit | Service calculates correct total |
```

### Planning Workflow

1. **Discuss** requirements with user → understand what needs to be built
2. **Create plan** → write it to `docs/plans/[feature-name].md`
3. **Review** → present plan to user, ask for approval
4. **Implement** → follow the plan step by step
5. **Update memory** → track progress in `.ai/memory.md` (ai-memory skill)
6. **Update plan status** → mark as completed when done

---

## 4. DATABASE.md Template

```markdown
# Database Documentation

> Generated: [date] | Last updated: [date]

## Entity Relationship Overview

[Mermaid ERD or text-based diagram]

## Tables

### users
| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | bigint | No | auto | Primary key |
| name | varchar(255) | No | - | User's full name |
| email | varchar(255) | No | - | Unique email |

**Relationships:**
- hasMany → posts, orders, invoices
- belongsToMany → roles (via role_user pivot)

**Indexes:**
- UNIQUE: email
- INDEX: created_at

[Repeat for each model/table]

## Enums

| Enum | Values | Used In |
|------|--------|---------|
| OrderStatus | pending, processing, shipped, delivered, cancelled | orders.status |

## Seeders

| Seeder | Purpose | Run in Production? |
|--------|---------|-------------------|
| RoleSeeder | Create default roles | Yes |
| UserSeeder | Test users | No (dev only) |
```

---

## 5. Ongoing Documentation Rules

### When to Update Documentation

- **New model/migration created** → Update DATABASE.md
- **New API endpoint** → Update API.md
- **Architecture decision made** → Add to ARCHITECTURE.md
- **Feature completed** → Update FEATURES.md, move plan to completed
- **Deployment process changes** → Update DEPLOYMENT.md

### Documentation Quality Rules

1. **Keep it terse** — documentation should be scannable, not a novel
2. **Use tables** — they're faster to read than prose
3. **Code examples** — show don't tell, include actual code snippets
4. **Timestamps** — always include "Last updated" dates
5. **Mermaid diagrams** — use for ERDs, flow charts, sequence diagrams when helpful
6. **Link to code** — reference actual file paths when possible
7. **Keep it in sync** — outdated docs are worse than no docs

### README.md Minimum Requirements

Every Laravel project README should have at minimum:

```markdown
# Project Name

[One paragraph description]

## Requirements
- PHP x.x+
- Composer
- MySQL/PostgreSQL
- Redis (if used)
- Node.js (if frontend)

## Installation
[Step-by-step local setup instructions]

## Configuration
[Key .env variables to set]

## Running
php artisan serve

## Testing
php artisan test

## Deployment
[Brief deployment instructions or link to docs/DEPLOYMENT.md]
```

---

## 6. AI-Driven Documentation Maintenance

When connected via MCP (Boost/Herd), **proactively use MCP tools to keep documentation accurate:**

- After running migrations → regenerate DATABASE.md table sections
- After adding routes → update API.md with new endpoints
- After installing packages → update ARCHITECTURE.md tech stack

> **Rule:** Treat documentation as part of the feature. A feature is not complete until its documentation is updated. When tracking progress in `.ai/memory.md`, include "Update docs" as a step in every implementation plan.

````
