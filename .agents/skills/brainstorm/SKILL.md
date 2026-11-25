---
name: brainstorm
description: "Pre-planning exploration for open-ended features or architectural decisions. Three phases: understand the problem, explore approaches, converge on direction. Produces a brainstorm note outside git. Does NOT produce code. Use before /plan when the problem space is unclear or multiple valid approaches exist. Invoke with /brainstorm."
argument-hint: "[topic, question, or issue number]"
---

# Brainstorm Skill

## Purpose

Exploratory thinking for problems where the solution direction is not obvious.
Brainstorm answers **"what should we build?"** — then `/plan` makes it concrete
with **"how do we build it?"**

This is NOT a replacement for `/plan`. Brainstorm converges on a direction;
plan produces an implementation spec.

## When to Use /brainstorm vs /plan

| Scenario | Start With |
|----------|------------|
| GitHub issue with clear requirements | `/plan` directly |
| Open-ended feature, multiple valid approaches | `/brainstorm` then `/plan` |
| Architectural decision (which pattern, library, structure) | `/brainstorm` |
| "How should we handle X?" questions | `/brainstorm` |
| Bug fix or well-scoped task | `/plan` directly |
| Spike or feasibility check | `/brainstorm` |

---

## CRITICAL: DO NOT CODE

**This skill is read-only exploration.** You must NEVER:

- Create or edit source files (`.dart`, `.yaml`, `.json`, etc.)
- Run `flutter`, `dart`, or build commands
- Produce implementation code blocks intended for copy-paste
- Modify any file other than the brainstorm output document

You MAY read code, search the codebase, and reference architecture — but only
to inform the exploration, never to implement.

The only file this skill creates is the brainstorm document itself. It is a
working note, not a deliverable: never stage, commit or push it, and never
create a branch or a worktree for it.

---

## Workflow

### Phase 1: Understand the Problem

**Goal:** Build a clear problem statement before exploring solutions.

1. **Parse the input.** If the argument is a GitHub issue number, fetch it:
   ```bash
   gh issue view <number> --json title,body,comments,labels,state
   ```
   Extract the core question or need. If the argument is a free-text topic,
   restate it as a clear problem statement.

2. **Search for prior art.** Check what already exists in the codebase:
   - If the topic has an issue number, read every existing note for it first:
     `tasks/*<number>*`, or wherever the project keeps plans and findings. A
     plan that already exists changes what is left to brainstorm
   - Use `Grep` and `Glob` for related features, models, BLoCs, repositories
   - Check `mobile/docs/` and `docs/` for existing design docs on the topic
   - Check `tasks/brainstorm_*`, `~/.claude/brainstorms/<repository-name>/`,
     and `mobile/docs/brainstorm/` for previous brainstorms
   - Check `tasks/lessons.md`, if you keep one, for relevant past mistakes or
     insights

3. **Gather protocol context.** If the topic involves Nostr:
   - Use `mcp__nostr__read_nip` for relevant NIPs
   - Use `mcp__nostr__read_kind` for event kind specifications
   - Check `docs/NOSTR_EVENT_TYPES.md` and `mobile/docs/NOSTR_VIDEO_EVENTS.md`

4. **Identify constraints.** Flag divine-mobile specific constraints that will
   shape any solution:
   - Layered architecture: UI → BLoC/Cubit → Repository → Client
   - BLoC-first for new state management (Riverpod is legacy)
   - Dark and light appearances: `context.vineColors` tokens, `VineTheme` and
     `divine_ui` components
   - Nostr protocol alignment requirements
   - Existing packages in `mobile/packages/` that may be relevant
   - Constructor injection, no widget helper methods

5. **Output to user:**
   - Problem statement (2-3 sentences)
   - What we know (existing code, prior art, protocol specs)
   - What we don't know (open questions, unknowns)
   - Constraints that apply

6. **Ask the user** one targeted question to validate understanding before
   proceeding. Prefer multiple-choice format:
   > "Before I explore approaches, is this the right framing?
   > 1. [Restatement A]
   > 2. [Restatement B]
   > 3. Something else — please clarify"

### Phase 2: Explore Approaches

**Goal:** Generate and assess 2-4 distinct approaches.

For each approach:

1. **Describe the approach** in 3-5 sentences. Be concrete — name which layers
   it touches, which packages it uses or creates, which patterns it follows.

2. **Assess against divine-mobile architecture:**
   - Which layers are affected? (UI, BLoC, Repository, Client)
   - Does it reuse existing packages in `mobile/packages/`?
   - Does it align with VineTheme and divine_ui component library?
   - Does it respect Nostr protocol constraints?
   - How complex is the testing strategy?
   - Does it introduce Riverpod dependencies or stay BLoC-first?
   - What is the migration risk if existing code is involved?

3. **Identify what the approach does NOT handle** — gaps, unknowns, risks,
   edge cases it punts on.

4. **Rate complexity:** Low / Medium / High

**Principles:**
- **YAGNI ruthlessly.** Eliminate complexity for hypothetical future needs.
  If an approach only wins on "flexibility for future requirements," that is
  a red flag, not a feature.
- **Boring is good.** Prefer proven patterns that match existing codebase
  patterns over novel approaches.
- **Right-size.** Match architecture to actual complexity. A simple feature
  does not need a new package.

Present approaches as a comparison to the user. Ask one follow-up question:
> "Which direction resonates, or should I explore a different angle?"

### Phase 3: Converge

**Goal:** Recommend a direction and hand off to `/plan`.

1. **Recommend** the best approach (or recommend gathering more information
   if the unknowns are too large to decide).

2. **Explain why** the recommended approach fits divine-mobile better than
   alternatives — be specific about architecture alignment, reuse, and
   simplicity.

3. **List open questions** that `/plan` will need to resolve. These are
   implementation details, not directional questions.

4. **Identify prerequisites** — things that need to happen before `/plan`:
   - Design mockups needed from Figma?
   - Protocol decisions that need team input?
   - New packages that need scaffolding?
   - Dependencies to evaluate?

5. **Suggest next step** — usually one of:
   - `/plan <issue-number>` to proceed with implementation planning
   - "Gather more info on X before planning"
   - "Discuss with team before committing to direction"

---

## Output Document

After convergence, choose the actual note path
`tasks/brainstorm_<issue-number-or-topic-slug>.md` from the repository root.
Set `note_path` to that path and run `git check-ignore -q -- "$note_path"`.
Use it only if the command succeeds. Create `tasks/` if it does not exist.

Otherwise, use
`~/.claude/brainstorms/<repository-name>/YYYY-MM-DD-<topic-slug>.md`.
Include the issue number in the slug for issue-specific notes.

Preserve existing notes. If the chosen filename already exists, add a unique
suffix and check the new path again before writing it inside the repository.

Never write the document under a tracked folder such as `docs/`. Tell the user
the path.

Use this template:

```markdown
# Brainstorm: <Topic>

Date: YYYY-MM-DD

## Problem Statement

[What are we trying to solve and why — 2-3 sentences]

## Constraints

- [divine-mobile specific constraints identified during Phase 1]

## Prior Art

- [Existing code, docs, or packages relevant to this topic]

## Approaches Explored

### Approach A: <Name>

**Description:** ...

**Layers affected:** [UI, BLoC, Repository, Client]

**Pros:**
- ...

**Cons:**
- ...

**Risks / Unknowns:**
- ...

**Complexity:** [Low / Medium / High]

### Approach B: <Name>

...

## Recommendation

[Which approach and why, or "need more information on X"]

## Open Questions for /plan

- [ ] Question 1
- [ ] Question 2

## Prerequisites

- [ ] Prerequisite 1

## Next Step

[/plan <issue>, or gather info on X, or discuss with team]
```

---

## Tool Reference

| Need | Tool |
|------|------|
| Fetch issue | `gh issue view <N> --json title,body,comments,labels,state` |
| Search code | `Grep` |
| Find files | `Glob` |
| Read source | `Read` |
| Nostr NIPs | `mcp__nostr__read_nip` |
| Nostr kinds | `mcp__nostr__read_kind` |
| Git history | `git log --oneline -20 -- <path>` |

The only file this skill writes is the brainstorm document.
