# Laravel Best Practice Skills for GitHub Copilot

A comprehensive set of GitHub Copilot agent skills that enforce Laravel best practices, coding standards, and architectural patterns across all your Laravel projects.

## What is this?

This is a collection of modular **GitHub Copilot Skills** — instructional documents that teach AI coding assistants (Claude, GPT-4o, Gemini, etc.) how to write Laravel code according to established best practices and your preferred conventions.

Once installed, these skills are automatically activated when you work on Laravel projects, so you never have to repeat coding instructions from scratch.

## Skills Included

| Skill | Description |
|-------|-------------|
| **laravel-general** | Core principles, conventions, project structure, philosophy |
| **laravel-architecture** | Design patterns — Services, Actions, DTOs, Repository pattern |
| **laravel-eloquent-database** | Eloquent best practices, migrations, relationships, query optimization |
| **laravel-api** | REST API design, API Resources, authentication, error handling |
| **laravel-testing** | Testing strategy with Pest/PHPUnit, factories, what & how to test |
| **laravel-security** | Validation, authorization, Form Requests, security hardening |
| **laravel-performance** | Caching, queues, jobs, database & application optimization |
| **laravel-frontend** | Blade components, Livewire, Inertia.js, Vite configuration |
| **laravel-code-style** | PSR-12, Laravel Pint, PHPStan/Larastan, naming conventions |
| **laravel-deployment** | Docker, CI/CD, environment configuration, monitoring |

## Installation

### Option 1: Install all skills globally (recommended)

```bash
npx skills add your-username/laravel-best-practice-skills@laravel-general -g -y
npx skills add your-username/laravel-best-practice-skills@laravel-architecture -g -y
npx skills add your-username/laravel-best-practice-skills@laravel-eloquent-database -g -y
npx skills add your-username/laravel-best-practice-skills@laravel-api -g -y
npx skills add your-username/laravel-best-practice-skills@laravel-testing -g -y
npx skills add your-username/laravel-best-practice-skills@laravel-security -g -y
npx skills add your-username/laravel-best-practice-skills@laravel-performance -g -y
npx skills add your-username/laravel-best-practice-skills@laravel-frontend -g -y
npx skills add your-username/laravel-best-practice-skills@laravel-code-style -g -y
npx skills add your-username/laravel-best-practice-skills@laravel-deployment -g -y
```

### Option 2: Install individual skills

Pick only the skills you need:

```bash
npx skills add your-username/laravel-best-practice-skills@laravel-architecture -g -y
```

### Option 3: Manual installation

Clone this repo and copy skill folders to your Copilot skills directory:

```bash
# Windows
copy /r laravel-* %USERPROFILE%\.copilot\skills\

# macOS/Linux
cp -r laravel-* ~/.copilot/skills/
```

## How It Works

1. **GitHub Copilot** reads the `SKILL.md` file description from each installed skill
2. When you work on a task that matches a skill's domain, Copilot automatically loads the relevant instructions
3. The AI follows those instructions when generating code, reviewing, or explaining
4. Works with **any AI model** in Copilot (Claude, GPT-4o, Gemini) — instructions are model-agnostic

## Customization

These skills represent opinionated best practices. Feel free to:

- Fork this repo and customize rules to match your team's conventions
- Remove skills you don't need
- Add your own project-specific skills alongside these
- Adjust code examples to match your preferred stack (e.g., Livewire vs Inertia)

## Model Compatibility

Skills are written as clear, structured Markdown instructions. They work equally well with:

- **Claude** (Anthropic) — optimized for instruction following
- **GPT-4o** (OpenAI) — follows structured rules well
- **Gemini** (Google) — handles markdown instructions effectively

The key is that instructions are explicit, specific, and example-driven — which all models handle well.

## Contributing

PRs welcome! If you have Laravel best practices to add or improve, please contribute.

## License

MIT
