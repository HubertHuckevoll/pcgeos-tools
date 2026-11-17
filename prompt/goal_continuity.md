
---
name: goal-continuity
description: Breaks large Codex plans into verifiable work chunks and enables reliable continuation of Codex Goals across usage limits and sessions.
---

# Goal Continuity

## Purpose

Execute complex Codex plans across multiple sessions.

Work autonomously in small, verifiable increments.
Preserve progress so that a new Codex session can resume
without access to the previous conversation.

The original overall goal must remain unchanged.
Interruptions and usage limits never constitute
completion of the goal.

## 1. Initialization

On every activation, check:

1. Does `.codex/goals/ACTIVE.md` exist?
2. Is there a matching, unfinished goal?
3. Do a plan and handoff document already exist?
4. Is the current repository state consistent with the handoff?

For an existing goal, read the handoff first.
Then verify the actual code state.

For a new goal, analyze the supplied plan.

Create the following files under `.codex/goals/<goal-id>/`:

- ORIGINAL_PLAN.md: The original, unmodified task description.
- PLAN.md: The structured implementation plan with work chunks.
- HANDOFF.md: The current state for the next session.

ACTIVE.md contains the identifier and path of the active goal.

Reuse existing documents instead of replacing them.

## 2. Divide the Plan into Chunks

First investigate the architecture, dependencies,
and affected areas of the codebase.

Divide the plan into small, preferably independent
work chunks.

Each chunk must contain:

- A unique identifier and description.
- A concrete, limited objective.
- Dependencies on preceding chunks.
- Affected files or components, where known.
- Verifiable acceptance criteria.
- Appropriate tests or other evidence of completion.

Prefer small, cohesive changes.

Each chunk should ideally be implementable and verifiable
within a single working session.

If a chunk is too large, subdivide it further.

Avoid chunks that leave partially implemented architectural
changes without a verifiable intermediate state.

Separate investigation, implementation, and integration
when doing so creates safer checkpoints.

Estimate effort only approximately.
Never treat estimates as guaranteed execution times.

## 3. Usage Budget Management

Explicitly account for the rolling five-hour usage window
and any additional Codex usage limits.

The five-hour window is not a guaranteed amount of
working time. Actual consumption depends on the model,
task complexity, and available usage budget.

Use reliable usage information when Codex exposes it.

In the CLI, users can inspect usage through `/status`.
Do not claim to read this information automatically
unless such access actually exists.

Check available usage whenever possible before starting
a substantial chunk and after completing one.

Rules:

- Do not start extensive changes when the remaining
  usage budget is known to be low.
- Reserve capacity for testing, error handling,
  and updating the handoff.
- When remaining usage is unknown, prefer smaller chunks.
- Prefer ending a chunk at a stable checkpoint.
- When approaching a usage limit, prioritize preserving
  the current state over starting new work.
- Never assume a final handoff can be written after
  a hard usage limit has been reached.

Therefore, checkpoints must be written throughout
execution, not only at the end of a session.

## 4. Chunk Execution

Work on only one chunk at a time.

Before starting:

1. Inspect the repository state, including existing changes.
2. Verify the chunk's assumptions against the actual code.
3. Record the chunk as IN_PROGRESS in the handoff,
   including its objective and intended changes.

During implementation:

- Keep changes within the chunk's scope.
- Respect existing architecture and repository rules.
- Record significant technical decisions.
- Update the checkpoint after important milestones.
- Preserve unrelated or pre-existing modifications.

After implementation:

1. Review the diff.
2. Run appropriate tests.
3. Address identified problems where feasible.
4. Document results and remaining limitations.
5. Mark the chunk VERIFIED only when its acceptance
   criteria have been demonstrably satisfied.

If verification is incomplete, mark the chunk
BLOCKED or UNVERIFIED.

Only then begin the next eligible chunk.

Never create commits or push changes autonomously.

## 5. Continuous Handoff

Update HANDOFF.md before each chunk, after significant
intermediate steps, and after completing each chunk.

The document must contain:

# Goal Handoff

## Overall Goal
Brief description and reference to ORIGINAL_PLAN.md.

## Status
ACTIVE / PAUSED / BLOCKED / COMPLETED

## Progress
Completed, ongoing, and pending chunks.
Reference to PLAN.md.

## Current Chunk
Identifier, objective, and execution status.

## Verified Findings
Confirmed technical findings with concrete file
and function references.

## Changes
Affected files and significant modifications.
Explicitly identify uncommitted and untracked files.

## Verification
Tests performed, results, and known failures.
List checks that have not been performed separately.

## Decisions
Important architectural decisions and their rationale.
Rejected approaches where relevant to future work.

## Open Issues
Blockers, risks, and unresolved assumptions.

## Next Action
The next concrete, immediately executable action.

## Resume Instructions
Brief instructions for safely continuing the work.

The handoff must be independently understandable.
It must not depend on inaccessible conversation history.

Keep it concise. Detailed planning belongs in PLAN.md.

## 6. Automatic Resume

Ensure once that the repository's existing AGENTS.md
contains a short continuity rule.

Append the following without overwriting existing rules:

"At the beginning of a session, check whether
.codex/goals/ACTIVE.md exists. When continuing the
active goal, read its HANDOFF.md and PLAN.md before
performing substantive work. Compare documented progress
against the actual repository state. Resume from the
first remaining necessary step. Ignore the goal state
when working on unrelated tasks."

On every resume:

1. Read ACTIVE.md and HANDOFF.md.
2. Read the relevant sections of PLAN.md.
3. Inspect git status and the affected files.
4. Compare documentation with actual code changes.
5. Verify whether the previous chunk was completed.
6. If a chunk is IN_PROGRESS, reconstruct its actual state.
7. Do not repeat work that is demonstrably complete.
8. Update the handoff if discrepancies are discovered.
9. Continue with the next necessary action.

Never blindly trust the documented state.
The actual code is authoritative regarding
implementation progress.

If the current thread has no active Codex Goal,
use the preserved overall objective as the basis
for resuming the work.

Do not invent or assume an active Goal status.

## 7. Session Interruption

When an interruption appears imminent:

- Do not start another chunk.
- Preserve the actual working state.
- Document remaining changes and pending verification.
- Update HANDOFF.md.
- Mark the goal PAUSED, not COMPLETED.
- Record the next concrete action.

A chunk may remain incomplete, but its state must
be unambiguously reconstructable.

If a hard limit interrupts execution unexpectedly,
the next session must be able to recover using
the latest checkpoint and the repository state.

## 8. Completion Criteria

The overall goal is complete only when:

- All required chunks have been verified.
- All original acceptance criteria are satisfied.
- Required integration checks have been performed.
- No unresolved critical regressions remain.
- The actual repository state matches the completed plan.

Only then mark the goal COMPLETED.

Remove the active reference from ACTIVE.md only if
it points to this completed goal.

Preserve the plan and handoff as permanent documentation.

## Core Principles

Work autonomously from chunk to chunk.

Do not stop unnecessarily after ordinary intermediate steps.
Interrupt only for blockers, actual usage limits,
or decisions that genuinely require user input.

Always prioritize:

Verifiable progress over volume.
Preserved state over new changes.
Resumability over speed.

First verify the root cause or assumption in the code,
then implement only the minimal confirmed fix.
