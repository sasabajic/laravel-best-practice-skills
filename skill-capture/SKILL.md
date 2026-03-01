````skill
---
name: skill-capture
description: Helper skill for capturing, extracting, and documenting coding patterns, rules, and best practices learned during coding sessions. Use when the user asks to save, export, capture, or document a pattern, convention, or rule they want to remember and reuse.
---

# Skill Capture — Extract & Save Coding Patterns

This skill helps you capture coding patterns, conventions, and rules from the current session and format them for inclusion in reusable skill files.

## When to Activate

Activate when the user says things like:
- "Save this rule"
- "Remember this pattern"
- "Add this to my skills"
- "Export this"
- "Create a skill for this"
- "Summarize what we learned"

## How to Capture a Skill

### Step 1: Identify What to Capture

When asked to capture/save something, identify:

1. **Category** — which existing skill does it belong to? (general, architecture, eloquent, api, testing, security, performance, frontend, code-style, deployment)
2. **Type** — is it a:
   - **Rule** (always do X, never do Y)
   - **Pattern** (code template/structure)
   - **Convention** (naming, organization)
   - **Configuration** (tool setup, config values)
3. **Priority** — is this a critical rule or a nice-to-have?

### Step 2: Format the Capture

Format the captured knowledge as a markdown section ready to paste into a SKILL.md file:

```markdown
## [Section Title]

### [Rule/Pattern Name]

[Clear explanation of WHAT and WHY]

```php
// GOOD — [description]
[code example of the correct way]

// BAD — [description of what to avoid]
[code example of the wrong way]
```

### Rules
- [Bullet point rule 1]
- [Bullet point rule 2]
```

### Step 3: Add to the appropriate SKILL.md

Append the formatted section to the relevant skill file, or create a new skill file if it doesn't fit any existing category.

## Capture Workflow — Quick Reference

When a user asks "save this" or "capture this pattern":

1. Summarize the pattern/rule in clear, imperative language
2. Provide a GOOD and BAD code example
3. List rules as bullet points
4. Identify the target SKILL.md file
5. Append to the file (or ask user to confirm the target)

## Session Summary Template

When the user asks for a session summary of learned patterns, format it as:

```markdown
# Session Learnings — [Date]

## New Rules Discovered
1. [Rule 1 — brief description]
2. [Rule 2 — brief description]

## Patterns Used
1. [Pattern — with brief code example]

## Conventions Established
1. [Convention — naming/structure decision]

## Suggested Skill Updates
- [ ] Add [rule] to [skill-name]/SKILL.md
- [ ] Add [pattern] to [skill-name]/SKILL.md
- [ ] Create new skill: [skill-name] for [topic]
```

## Creating a Brand New Skill

When the captured knowledge doesn't fit any existing skill:

```markdown
````skill
---
name: [skill-name]
description: [Clear description of when this skill should activate. Include keywords that trigger activation.]
---

# [Skill Title]

[Introduction — what this skill covers and why]

## [Section 1]
[Rules, patterns, examples]

## [Section 2]
[Rules, patterns, examples]
````
```

### New Skill Checklist

- [ ] Name is lowercase, hyphenated: `my-skill-name`
- [ ] Description clearly states WHEN to activate (include trigger words)
- [ ] Contains concrete code examples (GOOD/BAD)
- [ ] Rules are in bullet points
- [ ] Patterns have copy-pasteable code blocks
- [ ] Language is imperative ("Always do X", "Never do Y")

## Tips for Writing Effective Skills

1. **Be specific** — "Use `Carbon` for dates" not "Handle dates properly"
2. **Be imperative** — "Always use typed returns" not "It's good to use typed returns"
3. **Show, don't tell** — Include code examples for every rule
4. **Show both sides** — GOOD example + BAD example
5. **Keep it scannable** — Use headers, bullet points, tables
6. **Include the WHY** — Brief reason helps AI apply rules correctly
7. **Use trigger words** in description — helps Copilot know WHEN to load the skill

````
