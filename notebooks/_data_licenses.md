# Dataset License Registry

Every dataset pulled into `data/` must have a row here **before** its first
use in a notebook. Updates land in the same commit as the notebook that
introduces the dependency. When in doubt, mark the redistribution column
`No` — datasets can leave the repo with one mistaken commit, but cannot
un-leave.

| Dataset | Source URL | Records | License | Redistributable in-repo? | Used by | PII fields | Notes |
|---|---|---|---|---|---|---|---|
| _example_ UCI SMS Spam Collection | `archive.ics.uci.edu/ml/datasets/sms+spam+collection` | 5,574 | Research-only | No | H10, H12, H15 | none after scrub | Binary `spam`/`ham`; classic baseline |

## Audit checklist before adding a row

- [ ] Read the original source's license page (not a third-party mirror's claim).
- [ ] Confirm the redistribution clause — many "free" datasets allow training but forbid bundling the raw text.
- [ ] List every PII field present (phone numbers, names, account numbers, addresses) so the scrub step in H9.5 knows what to strip.
- [ ] Note any rate limits or auth requirements that affect Colab download cells.
