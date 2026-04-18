# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-04-17

### Added

- **New skill: `laravel-filament`** — Filament 3 admin panels, resources, forms, tables, widgets, standalone components, multi-tenancy
- **New skill: `laravel-real-time`** — Broadcasting with Laravel Reverb, Echo, channels, presence, notifications
- **New skill: `laravel-error-handling`** — Exception handling strategy, custom exceptions, error reporting, production error pages
- **New skill: `laravel-localization`** — Multi-language support, translation files, locale middleware, date/number formatting
- **New skill: `laravel-notifications`** — Notification channels, mail/database/broadcast/SMS, on-demand notifications, queuing
- **New skill: `laravel-scheduling`** — Task scheduling, console commands, cron patterns, overlapping prevention, maintenance mode
- `CHANGELOG.md` — Version tracking for skill releases
- `CONTRIBUTING.md` — Guidelines for contributing new skills
- Skill dependency Mermaid diagram in README

### Changed

- **`laravel-architecture`** — Added Pipeline pattern, Value Objects, DDD folder structure, anti-patterns section
- **`laravel-eloquent-database`** — Added UUID/ULID keys, full-text search (Scout), polymorphic relationships, transactions, model pruning
- **`laravel-api`** — Added API documentation (Scramble), CORS configuration, webhook handling, bulk operations
- **`laravel-testing`** — Added browser testing (Dusk), architecture testing (Pest), mutation testing (Infection)
- **`laravel-security`** — Added 2FA, CORS setup, Content Security Policy, signed URLs, `composer audit`
- **`laravel-performance`** — Added Laravel Octane, image optimization, connection pooling, HTTP caching headers
- **`laravel-frontend`** — Added SSR with Inertia, PWA setup
- **`laravel-code-style`** — Added Rector PHP, Git hooks for code quality
- **`laravel-general`** — Added middleware best practices section
- Updated README with all new skills, version badge, and skill dependency diagram
- Cross-reference links standardized across all skills
- Backward compatible with Laravel 10+ with upgrade recommendations where applicable

## [1.0.0] - 2026-04-15

### Added

- Initial release with 12 skills:
  - `laravel-general` — Core principles, conventions, project structure
  - `laravel-architecture` — Services, Actions, DTOs, Repository pattern
  - `laravel-eloquent-database` — Eloquent best practices, migrations, queries
  - `laravel-api` — REST API design, Resources, Sanctum auth
  - `laravel-testing` — Pest/PHPUnit testing strategy
  - `laravel-security` — Validation, authorization, security hardening
  - `laravel-performance` — Caching, queues, optimization
  - `laravel-frontend` — Blade, Livewire, Inertia.js, Vite
  - `laravel-code-style` — PSR-12, Pint, PHPStan/Larastan
  - `laravel-deployment` — Docker, CI/CD, environment config
  - `laravel-project-docs` — Project analysis, planning, documentation
  - `ai-memory` — Persistent AI memory and session continuity
- `skill-capture` — Meta-skill for capturing patterns from sessions
- Install scripts for Windows (PowerShell) and macOS/Linux (bash)
- Prompt templates for skill management
