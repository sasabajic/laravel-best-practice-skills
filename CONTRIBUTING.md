# Contributing to Laravel Best Practice Skills

Thank you for considering contributing to this project! This guide will help you create high-quality skills that are consistent with the existing collection.

## How to Contribute

### 1. Adding a New Skill

Create a new folder with a `SKILL.md` file:

```
my-skill-name/
└── SKILL.md
```

#### Naming Convention

- Folder name: lowercase, hyphenated — `laravel-{topic}`
- Example: `laravel-queue-monitoring`, `laravel-multi-tenancy`

#### SKILL.md Structure

Every skill must have:

1. **Frontmatter** with `name` and `description` (include activation trigger words)
2. **Clear sections** organized by subtopic
3. **Code examples** for every rule (GOOD + BAD patterns)
4. **Bullet-point rules** for quick scanning
5. **Cross-references** to related skills using the format: `> See also: **laravel-{skill}** skill`

```markdown
---
name: my-skill-name
description: Clear description of when this skill activates. Include keywords and trigger phrases.
---

# Skill Title

[Introduction — what this skill covers and why]

## Section 1

### Rule/Pattern Name

[Explanation of WHAT and WHY]

```php
// GOOD — description
[correct code example]

// BAD — description
[incorrect code example]
```

### Rules

- Rule 1 (imperative voice: "Always do X", "Never do Y")
- Rule 2
```

#### Quality Checklist

- [ ] Frontmatter `description` includes trigger words for Copilot auto-activation
- [ ] Every rule has a concrete code example
- [ ] GOOD and BAD examples are clearly labeled
- [ ] Rules use imperative voice
- [ ] Cross-references to related skills are included
- [ ] Code examples follow PHP 8.1+ syntax
- [ ] Examples are backward compatible with Laravel 10+ (note when features require newer versions)
- [ ] No duplicate content — use cross-references instead of copying

### 2. Improving an Existing Skill

- Add new sections at the end of the file (before the last section)
- Don't remove or significantly alter existing content
- Keep the same formatting style
- Update cross-references if adding related content

### 3. Fixing Issues

- Fix typos, broken examples, or outdated patterns
- Update Laravel version references when new versions are released
- Fix code examples that don't follow their own rules

## Style Guide

### Writing Style

- **Be specific** — "Use `Carbon` for dates" not "Handle dates properly"
- **Be imperative** — "Always use typed returns" not "It's good to use typed returns"
- **Show, don't tell** — Include code examples for every rule
- **Show both sides** — GOOD example + BAD example
- **Keep it scannable** — Use headers, bullet points, tables
- **Include the WHY** — Brief reason helps AI apply rules correctly

### Code Examples

- Use `declare(strict_types=1)` in all PHP examples
- Use typed parameters and return types
- Use `final` classes unless inheritance is needed
- Use `readonly` properties where applicable
- Follow PSR-12 and Laravel Pint conventions

### Cross-References

When referencing another skill, use this format:

```markdown
> See also: **laravel-security** skill for detailed validation patterns.
```

## Versioning

This project uses [Semantic Versioning](https://semver.org/):

- **Major** (X.0.0) — New skills added or significant restructuring
- **Minor** (0.X.0) — Existing skills expanded with new sections
- **Patch** (0.0.X) — Bug fixes, typo corrections, small updates

Update `CHANGELOG.md` with your changes.

## Submitting

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/add-my-skill`
3. Make your changes
4. Update `CHANGELOG.md`
5. Submit a Pull Request with a clear description

## Questions?

Open an issue if you're unsure about anything. We're happy to help!
