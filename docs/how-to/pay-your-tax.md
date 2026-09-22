---
id: ricestax.how-to.pay
kind: how-to
title: Pay a project's tax
---
# Pay a project's tax

Run everything at the root of the project, where `canon.yaml` is. Assess first, so every comment,
decision, reference, page, name, mutant, and gap has a row in `canonical_vetting/`:

```
ricestax assess
```

Then open the page and decide:

```
ricestax pay 8080
```

The page opens on the Why queue; `#what`, `#how`, and `#all` in the URL open the others. A Why card
shows the comment and the code it explains, with what it cites; a What card shows the name and the
signature with the body beneath them; a How card is wavelet's mutant card, whole. Each decision is
written into its ledger file in the working tree the moment it is clicked, and nothing else changes,
so review what `git diff` shows and commit it: the committer of the verdict line is its signer.
ref:DEC-ui-commit ref:DEC-signer

A subject that cannot be paid yet is exempted rather than ignored, so the debt stays counted: use
"Exempt this subject…" under the switcher, or write the entry yourself in
`canonical_exemptions.yaml` with the kinds it covers, a reason, and the version to revisit by. Lift it
from the Exempt section when the debt is paid. ref:DEC-exemptions

When the How queue says files changed since the run, or when the code has moved on, press
"run mutation": it runs the command `canon.yaml` names under `runtime`, shows the run's last line
while it goes, and re-reads the project when it ends. Keep deciding meanwhile; a decision on a
mutant that is the same after the run carries over, and one whose mutant is absent remains unverified until the current report provides evidence.
The How queue separates Needs attention, Decisions, and History. A recorded kill
resolves an earlier testing-gap decision. Archive resolved decisions individually
or in bulk; Undo or Restore brings them back. An absent or reclassified decision
can be retired with an explicit reason, which does not claim a kill. The same code, tests, and seed give the same run, so
changes to the code, catalog, tests, or seed may change the result. ref:DEC-mutation-rerun

Finally prove the tax is paid:

```
ricestax audit
```

It fails while any row is open, stale, uncommitted, unrecorded, untangled, or past its revisit
version, and passes otherwise. ref:DEC-audit

Archive, restore, and retirement append events to `canonical_history/mutations.yaml`.
Each event retains the original verdict and note, its source digest, the mutation
diff, run facts, a SHA-256 evidence checksum, and a link to the previous event for
that decision. The original `canonical_vetting/` row is not rewritten. Review and
commit the history file: uncommitted history remains an audit finding. History is
separate from the build output, so cleaning `.mut/` does not remove it.

Results are rechecked before every history change. If another review or run changed
the revision, reload and retry. The writer uses a short-lived directory lock at
`canonical_history/.lock`; if a process crashes while holding it, verify that no
review writer is running before removing the stale lock directory.

The server records mutation attempts in `.mut-attempt.json`. A failed/interrupted
attempt keeps the page from presenting a previous report as verified current results.
Rerun through the UI to record completion. An archived mutation that returns as a
survivor or changes source context reappears in Needs attention.
