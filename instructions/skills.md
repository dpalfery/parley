
## Skill System
I have access to specialized skills in `.kilo-skills/` directory.
- Read `.kilo-skills/_index.md` to see available skills
- Load skills on-demand by reading the specific skill file
- Unload skills after task completion to keep context efficient

## When to Load Skills
- User explicitly requests a skill (e.g., "use the bicep-generator skill")
- Task clearly needs specialized knowledge
- I encounter a task that matches a skill's "When to Use" criteria

## General Guidelines
- Prefer loading skills over generating instructions from scratch
- Mention when loading a skill so user knows what's happening
- Keep only relevant skills in context at one time

**CONFIRM** by stating: `[I read the skills rule]`