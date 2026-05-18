# v2 E2B 4-bit Marker Extraction Sweep

Prompt artifact: `../prompts/v2_marker_extraction_prompts.md`

Metric artifact: `../results/v2_e2b_4bit_prompt_feature_metrics.csv`

Purpose: completed two-prompt marker extraction sweep with tighter definitions
for sender identity, impersonation, fabricated context, payment requests, and
external actions.

Coverage:

- E2B 4-bit only.
- 8-bit was skipped for this prompt generation because of runtime/memory
  constraints.

Result snapshot:

| Prompt | Examples | Accuracy | Precision | Recall | F1 | Parse failure rate |
|---|---:|---:|---:|---:|---:|---:|
| Prompt 1 - Literal Observable Checklist | 45 | 0.733 | 0.944 | 0.607 | 0.739 | 0.067 |
| Prompt 2 - Conservative Binary Extractor | 45 | 0.600 | 0.917 | 0.393 | 0.550 | 0.022 |

Decision: v2 is the best completed ablation record, but recall was too low for
the user-safety target. Continue with v3 refinements.

