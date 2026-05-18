# Prompt Ablation Experiment Log

This directory is the GitHub-facing record for the prompt ablation work behind
`../11_prompt_ablation.ipynb`. It keeps prompt versions, small metric tables,
and short run notes separate from the raw Drive/Colab scratch files.

Large notebooks, caches, prediction dumps, and imported Drive folders are kept
out of version control under `../_archive/`.

## Version Lineage

| Version | Prompt artifact | Meaning | Quantization coverage | Status |
|---|---|---|---|---|
| v0 | `prompts/v0_zero_shot_verdict_prompts.md` | Early verdict/probability prompts. Useful as the baseline prompt family. | 8-bit and 4-bit attempts in scratch logs | Historical baseline |
| v1 | `prompts/v1_marker_extraction_prompts.md` | First marker-extraction framing: separate observable scam markers from final verdict logic. | 8-bit and 4-bit attempts in scratch logs | Historical ablation |
| v2 | `prompts/v2_marker_extraction_prompts.md` | Completed two-prompt marker extraction sweep with tighter field definitions. | 4-bit only due to runtime/memory constraints | Best completed ablation |
| v3 | `prompts/v3_final_smoke_prompts.md`, `prompts/v3_prompt1_refined.md` | Current refinement line focused on harder fabricated-context/soft-pressure cases. The smoke metrics use the final-smoke prompt set; `v3_prompt1_refined.md` is the active Prompt 1 draft. | 4-bit only due to runtime/memory constraints | Active candidate |

## Committable Evidence

Commit these files when publishing the prompt ablation story:

- `README.md`
- `prompts/*.md`
- `runs/*.md`
- `results/*_metrics.csv`

Do not commit raw image datasets, Colab caches, model weights, generated
prediction dumps, or full Drive imports. Recreate long logs when needed and
summarize their decisions here.

## Current Result Snapshot

| Run | Dataset size | Accuracy | Precision | Recall | F1 | Parse failure rate | Decision |
|---|---:|---:|---:|---:|---:|---:|---|
| v2 E2B 4-bit two-prompt sweep | 45 | 0.733 | 0.944 | 0.607 | 0.739 | 0.067 | Good precision, recall too low |
| v3 E2B 4-bit final smoke | 185 | 0.897 | 0.958 | 0.913 | 0.935 | 0.000 | Strong current candidate; recreate logs before final claim |
