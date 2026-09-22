---
id: ricestax.design.mutant-decision-lifecycle
kind: explanation
title: Mutant decisions across runs
---
# Mutant decisions across runs

Design proposal and implementation notes, 21 September 2026.

Release 0.2.0 implements the lifecycle views, archive/restore/undo,
reasoned retirement, retained evidence, source-manifest checks, and stale-write
rejection described here. It was published to npm on 22 September 2026 and verified with a clean registry
installation. Publication used an explicit owner-authorized exception to the
failing self-audit, recorded in `dist/0.2.0/RELEASE.md`; the audit did not pass.

The storage implementation uses one versioned `canonical_history/mutations.yaml`
log rather than one file per mutant, so a bulk action can be committed with one
atomic rename. Its events include `eventDecisionDigest`, `eventSnapshot`,
`eventFacts`, `eventEvidenceDigest` (SHA-256), and `eventPrevious`. Canon’s original
verdict shards are unchanged. Tests cover persistence, stale requests, returning
survivors, missing reports, tampered snapshots, and audit checks; the packed WASM
application has also passed the real-browser archive/undo/restore flow on an
isolated copy of Offscript. Drivers without `source-sha256.json` retain the older
mutation-span freshness check, explicitly labeled in the run summary.

The sections below record the design rationale. The standalone HTML remains a
simulation for exploring alternate states, not a connection to the live ledger.

Open [the interactive prototype](../design/mutant-decision-lifecycle.html) in a browser.
It needs no build or network. All actions are local to that page and reset on
reload. The scenario selector demonstrates alternate run conditions explicitly;
it does not execute a mutation command or change a ledger.

## The problem in the original screen

`web/app/Main.hs` groups decisions by whether they predate this browser session.
An empty working queue therefore says “This session -- 0 of 0 still undecided”
while three large `gone` cards remain below it. This makes completed work look
unfinished, hides the original mutation behind an identifier, and suggests
that deleting evidence is the way to finish.

`assemble` in `docs/reference/core.md` / `src/RicesTax/Core.hs` finds these rows
by comparing ledger entries to the **live** How queue. `liveMutants` contains only
survived/uncovered entries. `goneItem` then conflates killed mutants, missing runs,
and other absent entries. The reader in `docs/reference/sydtest.md` retains the
full report in `runMutants`, so known kills can be distinguished before the UI
receives its payload. No inference from a missing live obligation is necessary.

The pre-0.2 API had decision writes but no archive/restore operation, and a single
`state` without explicit resolution or archival evidence. The implementation
therefore changes the core, ledger integration, API, and frontend; relabeling
`gone` in CSS or JavaScript would not establish the required evidence.

## The screen the user should see

Keep the project, Why/What/How navigation, and subject filter. Within How, replace
session-based grouping with **Needs attention**, **Decisions**, and **History**.
These views describe work, not when a browser tab happened to open.

Put a compact run summary above those views: completion time, baseline/control
status, catalog scope, killed/survived/inconclusive counts, and source freshness.
A link expands the run identity, retained logs, command, and checksums. An actual
production “Run mutation” action uses the existing configured command and shows
progress; keep the last completed results visible, labeled as previous results,
until the new attempt finishes. A failed attempt must not replace them with an
empty green queue.

For the supplied Offscript case:

> Latest completed run · 8 killed · 0 survived · baseline passed
>
> **No decisions needed**
>
> The latest completed run has no surviving mutants in its eight-site catalog.
>
> **3 earlier testing-gap decisions are now resolved**
>
> [Review resolved decisions]

The “Decisions” view shows three compact rows. Each has a human-readable mutation
name, file, `Resolved · now killed`, and **Earlier decision: Inadequate testing**.
The outcome does not overwrite the verdict. Expand “Decision and run evidence”
to see the actual change, identity, original note and signer, original run, and
current result. Omit empty “Cites nothing” and repeated generic “material” prose.
Use “Saved locally · not committed” for unsigned local decisions.

Each resolved row offers **Archive decision**. The view offers
**Archive resolved decisions (3)**. There is no confirmation modal for this
reversible operation: show a persistent Undo message until another action, and
allow restoration from History after the message is gone. No automatic archival;
a person can inspect the new evidence first. Counts update immediately only after
a successful server response. A failed save leaves the row in place and explains
that no change was saved.

## Separate three kinds of state

Store and display the human verdict, latest observed result, and archive state
independently. “Approved mutant” is not a useful umbrella: an equivalence judgement
and an inadequate-testing judgement mean different things.

| Evidence | UI state and location | Action |
| --- | --- | --- |
| Same mutation explicitly killed in a completed, control-green report matching the source snapshot | Resolved · now killed; Decisions | Archive, individually or in bulk |
| Same mutation survives with an inadequate-testing decision | Testing gap remains; Needs attention | Inspect change/tests and rerun; do not ask for the same verdict unnecessarily |
| Same mutation survives with a still-valid equivalence decision | Survived · accepted as equivalent; Decisions | Inspect/revisit decision; display test outcome unchanged |
| Source/context or mutation identity changed | Review again; Needs attention | Make a fresh decision; link the historical one |
| Entry absent from a narrower catalog | Absent · unverified; Needs attention | Inspect scope, restore selection, or explicitly retire the old decision |
| No readable report, interrupted attempt, failed controls, stale source, timeout, invalid compilation, or infrastructure error | Verification needed; Needs attention | Explain the specific failure and rerun; never count as resolved |
| Same mutation now raised as a coverage gap instead of a judgement | Reclassified as coverage gap | Link directly to its current obligation; do not duplicate the work |
| Resolved decision archived by the user | Archived; History | View evidence, search, restore |
| An archived mutation survives again | Return to Needs attention with “Survived again” | Retain archival history; require the applicable testing/review work again |

A known kill does not require all eight other sites to match the previous catalog;
it requires affirmative evidence for this exact mutation and valid run controls.
Conversely, a completed full-catalog run alone does not prove that an absent entry
was killed. Preserve explicit statuses from the driver rather than flattening
invalid compilation and infrastructure errors into “skipped.”

“Retire decision…” is a secondary action for a deliberately removed mutation or
contract. Require a reason, show “Retired · no current test result,” and retain it
in History. This records a scope change; it must not manufacture a kill, remove
an active coverage obligation, or silence an unhealthy-run warning. Do not offer
bulk retirement for unresolved entries. This less-common flow is specified here;
the prototype concentrates on verified archival and does not implement retirement.

Restoring a historical decision changes its visibility, not its validity. If its
source no longer matches or a new result requires work, restore into Needs
attention, not Decisions. Archived acceptance must not silently authorize changed
code. If an identical accepted-equivalent mutation returns, show the carried
verdict explicitly; any automatic carry-over must satisfy existing context and
provenance checks.

## History and audit

History provides status filters (resolved, retired, reclassified), search by
mutation/file/decision, and the original and closing run links. Archive metadata
includes time, reason, reference to the decision, and the evidence snapshot used
at the time. Signing follows the existing working-tree/commit convention.

Archive is not deletion. Preserve the original verdict, note, source digest,
run, and commit attribution. Never alter a signer by rewriting the original
verdict as “resolved.” Use separate archival metadata or an append-only event
record. Permanent deletion is not part of routine review.

Do not force the user to archive to obtain a clean work queue. Uncommitted ledger
changes remain subject to the existing audit policy. Archive itself must not
make `audit` pass: active obligations, stale material, and unusable run evidence
retain their existing checks. Keep review progress and repository/audit health
separate in both counters and language.

All counts follow the active subject filter, except a clearly labeled project run
summary. An empty filtered view says “No decisions needed in this subject”; a
project-wide absence of results says “No current run available.” Never style an
unavailable run as successful. Status words accompany colors. Use keyboard-accessible
buttons, visible focus, native disclosure controls, and a narrow-screen stacked
layout. Announce save/undo results to assistive technology and preserve focus
when a row disappears.

## Data and implementation requirements

1. Classify outcomes in the core using **all** current report entries, not just
   live obligations. Preserve run parse errors and completeness/control status.
   Capture the old material at decision time so missing-source rows retain names
   and diffs; do not reconstruct it from potentially changed current files.
2. Give the frontend separate fields for `decision`, `currentObservation`,
   `resolution`, and `archive`. Include explicit evidence reasons, original/current
   run identifiers, source digests, and the exact driver outcome. Do not ask the
   frontend to interpret free-text `gone` explanations.
3. Add archive/restore/retire operations with an expected ledger revision and run
   identity. The server rechecks eligibility; a newer run produces “Results changed;
   reload before archiving.” Make bulk archive atomic or explicitly report every
   saved/failed row; do not silently clear partially saved work.
4. Preserve stable mutation identity and context checks. Do not match by ordinal
   on screen, shortened filename, title, or line number alone. If the historical
   identity cannot be joined, say unverified. A same-identity kill can resolve an
   old testing-gap judgement even when the implementation has been improved;
   carrying an equivalence judgement onto changed code is a separate question.
5. Apply backend changes to the literate sources in `docs/reference/` and regenerate
   their tangled Haskell; implement views in `web/app/Main.hs`. Rebuild both native
   and browser artifacts so the served frontend and wire contract agree.

## Verification before shipping the implementation

- Match known killed entries to historical decisions, and preserve the original
  inadequate-testing verdict and note after archive, restart, and restore.
- Missing, partial, failed, stale, and inconclusive runs never become kills or a
  green “no work” result; a run-level warning survives any retirement action.
- Archive three resolved decisions, undo, archive one, reload, restore it. Counts,
  contents, provenance, and audit obligations remain correct throughout.
- Simulate a new run during archival: refuse stale writes without losing decisions.
- Simulate an archived mutant surviving again and a changed mutation/context. Work
  reappears; old acceptance cannot hide it. Test reclassification without duplicates.
- Check narrow-screen layout, keyboard navigation, focus after removal, live save
  announcements, expanded diffs, subject filters, and History search.
- Compare the native CLI and rebuilt browser payload on Offscript. Verify that the
  three old records are resolved because their report entries are killed, not merely
  because `liveMutants` is empty. Assert that archiving cannot waive audit failures.

## Evidence behind the prototype’s default scenario

Read from Offscript on 21 September 2026:
`.mut/runs/2026-09-21T15-48-48.247424Z-11398b6f-9fbf-41b9-b185-fc7b13ae2984`.
The completed report has one passed control, zero failed controls, and eight
killed entries. Every entry says `generated_properties: killed`.

Reproducing Rice’s Tax’s FNV identity calculation from the reported module,
binding, operator, original expression, replacement, and occurrence ordinal joins:

| Historical decision | Current mutation | Result |
| --- | --- | --- |
| `mutant/f5945b803b0d` | `country-native-validation-bypass` | killed |
| `mutant/cd96a2dc264e` | `country-json-depth-unbounded` | killed |
| `mutant/26d6e3b0148f` | `holiday-json-depth-unbounded` | killed |

The ledger files still say `inadequate-testing`, with no note and original run
`refine-source-mutation-1-seed-9dd0a5`. The prototype uses these real identities
and facts. Alternate scenarios are deliberately labeled simulations. No production
review data was edited to construct this design.

## Prototype verification

Checked in headless local Chrome on 21 September 2026: the default real-data
summary and evidence disclosure; bulk archive and undo; individual archive and
restore; History search including no matches; all five alternate situations;
archiving only the two known kills in the partial-catalog situation; and a
390-pixel mobile viewport without horizontal overflow. No JavaScript errors
were emitted. Desktop and mobile screenshots were visually inspected.

These checks exercise the prototype only. The production implementation and its
ledger/run regression tests listed above remain future work.
