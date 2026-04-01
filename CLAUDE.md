# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 48 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Godot 4.6.2 (installed at `~/Desktop/Godot_v4.6.2`; project root at `src/`)
- **Language**: GDScript (primary); GDExtension for performance-critical native code if needed
- **Rendering**: Forward+ (3D, WebGL export)
- **Physics**: Godot Jolt (default in 4.6)
- **Export Target**: HTML5/WebGL (primary); desktop as dev convenience build
- **Version Control**: Git with trunk-based development
- **Build System**: Godot export presets (HTML5 + desktop)
- **Asset Pipeline**: Godot native import system; .tres Resources for data

> **Note**: Use `godot-specialist` and `godot-gdscript-specialist` agents.
> Godot 4.4–4.6 introduced significant changes beyond LLM training cutoff —
> always cross-reference `docs/engine-reference/godot/` before suggesting APIs.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md
