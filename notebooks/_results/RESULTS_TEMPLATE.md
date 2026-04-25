# Results — &lt;notebook name&gt;

> **Notebook:** `NN_short_topic.ipynb` &nbsp;|&nbsp; **Spec / task:** `Hxx` in [`tasks/99_humantasks.md`](../../tasks/99_humantasks.md) &nbsp;|&nbsp; **Run by:** &lt;name&gt; &nbsp;|&nbsp; **Date:** `YYYY-MM-DD`

## Headline numbers

| Metric | Value | Threshold | Pass? |
|---|---|---|---|
| Macro-F1 | 0.xx | ≥ 0.xx | ☐ |
| Scam-class recall | 0.xx | ≥ 0.xx | ☐ |
| First-token latency (p50) | xx ms | ≤ xx ms | ☐ |
| Tokens / sec | xx | ≥ xx | ☐ |

## Setup

- **Model:** `<hf-id>` @ revision `<commit-hash>`
- **Quantisation:** `<e.g. nf4 4-bit via bitsandbytes>`
- **Dataset:** `<name + split + size>` — license: `<from _data_licenses.md>`
- **Hardware:** Colab `<T4 / A100 / CPU>`
- **Seeds:** `torch=0`, `numpy=0`, `random=0`

## Findings

- (one bullet per finding — what the data **says**, not what you hoped it
  would say)
- ...

## Decisions feeding back into the runtime

For every decision: name the file + symbol that needs updating, so this
notebook isn't a dead-end.

- e.g. _"Set τ_high = 0.78 in `ios/App/App/GemmaPlugin.swift` `kScamThresholdHigh`"_
- e.g. _"Drop `ja` from the languages array in `src/app/settings/page.tsx` until F1 ≥ 0.85"_
- e.g. _"Replace prompt template in `analyse()` with format C from §H11.1"_

## Known limitations / next runs

- (what this notebook didn't cover; what the next sibling notebook should
  pick up)
- ...

## Reproduce

1. Open and run `00_environment.ipynb` to pin library versions.
2. Open and run `NN_short_topic.ipynb` end-to-end — completes on free Colab
   T4 in ~XX min.
3. CSVs land in `_results/csv/<NN>_<run-date>.csv` for diffing future runs.

## Run history

| Date | Notes | Macro-F1 | Δ from last |
|---|---|---|---|
| YYYY-MM-DD | initial | 0.xx | — |
