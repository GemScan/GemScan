# v3 E2B 4-bit Final Smoke

Prompt artifact: `../prompts/v3_final_smoke_prompts.md`

Metric artifact: `../results/v3_e2b_4bit_final_smoke_metrics.csv`

Purpose: test the refined marker-extraction prompt set against a larger smoke
set, with special attention to fabricated context, soft emotional pressure, and
same-thread reply handling. `../prompts/v3_prompt1_refined.md` remains the
active Prompt 1 draft for the next iteration.

Coverage:

- E2B 4-bit only.
- 8-bit was skipped because of runtime/memory constraints.

Result snapshot:

| Prompt | Examples | Accuracy | Precision | Recall | F1 | Parse failure rate |
|---|---:|---:|---:|---:|---:|---:|
| Prompt 2 - Conservative Binary Extractor | 185 | 0.897 | 0.958 | 0.913 | 0.935 | 0.000 |

Decision: v3 is the strongest current candidate, but mark it as active until the
logs are recreated and the final notebook/report references the same run.
