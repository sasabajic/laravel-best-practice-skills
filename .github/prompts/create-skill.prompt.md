---
mode: agent
description: "Create a new skill file from a description of rules and patterns."
---

# Create New Skill

I want to create a new skill. Here's what I need:

**Skill topic**: {{ topic }}

Based on the topic above, create a new SKILL.md file with:

1. Proper frontmatter with `name` and `description` (include activation trigger words)
2. Clear sections organized by subtopic
3. Code examples for every rule (GOOD + BAD patterns)
4. Bullet-point rules for quick scanning
5. Naming conventions table if applicable

Place the file at: `~/.copilot/skills/{{ skill-name }}/SKILL.md`

Follow the same format and quality as the existing Laravel skills in this project.
