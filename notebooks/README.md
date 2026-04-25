# notebooks/ — Model Capability Validation

Workspace for the non-device validation tasks **H8–H17** in
[../tasks/99_humantasks.md](../tasks/99_humantasks.md). Every notebook here is
a Colab-runnable experiment that proves one specific spec promise before it
hardens into runtime code.

## Layout

```text
notebooks/
├── README.md                 this file — playbook + conventions
├── .gitignore                excludes data/, models/, ipynb checkpoints, W&B logs
├── _data_licenses.md         H9.2 — license registry for every dataset pulled
├── _results/                 one results file per notebook run
│   └── RESULTS_TEMPLATE.md   copy this when starting a new run
├── data/                     datasets land here (gitignored)
└── 00_environment.ipynb      H8.5 — pinned library versions; run first
```

Notebook naming: `NN_short_topic.ipynb`. Numbering matches the H-task so a
reviewer can pair a notebook with the spec promise it validates.

## Planned notebooks

| File | Task | Purpose | Decision output |
|---|---|---|---|
| `00_environment.ipynb` | H8.5 | Pin `transformers` / `mlx-lm` / `datasets` versions | None — env baseline |
| `10_baseline_zeroshot.ipynb` | H10 | Zero-shot Gemma E2B vs E4B on UCI + Kaggle | Default tier choice |
| `11_prompt_ablation.ipynb` | H11 | Prompt-format sweep on hard cases | Winning template → `analyse()` system prompt |
| `12_threshold_sweep.ipynb` | H12 | Confidence threshold + calibration | (τ_high, τ_low) → plugin constants |
| `13_multilingual.ipynb` | H13 | Per-language F1 across en/es/hi/zh/ja | Settings language gating |
| `14_adversarial.ipynb` | H14 | Robustness to paraphrase / leet / homoglyph / injection | Prompt hardening + red-team fixtures |
| `15_distillation.ipynb` | H15 | Gemma → DistilBERT teacher-student | SMS triage tier viability |
| `16_latency.ipynb` | H16 | CPU latency proxy for iPhone | Voice Agent §3.4a budget |

## Conventions

### Starting a notebook

1. Open in Colab: `File → Open notebook → GitHub` and paste the path to the
   `.ipynb`. (You'll need a GitHub-Colab link only after pushing.)
2. Run `00_environment.ipynb` first in this kernel — it pins library versions
   so later notebooks don't drift.
3. New notebook? Copy the imports + path setup from the closest existing
   sibling. Don't re-invent the kernel state.

### Logging results

After every meaningful run, copy `_results/RESULTS_TEMPLATE.md` to
`_results/NN_short_topic.md` (matching the notebook filename) and fill in:

- Headline metrics in the table at the top (so reviewers can scan the
  directory without opening notebooks)
- Decisions that feed back into runtime code, with the file/line that needs
  updating
- Known limitations + suggested next runs

If you re-run a notebook with different inputs, append a new dated section to
the same `_results/NN_*.md` file rather than overwriting — historical
comparisons are usually what reveal regressions.

### Datasets

- Pull into `notebooks/data/` — gitignored. Most scam corpora are
  research-only and **cannot** ship in-repo.
- Every dataset gets a row in `_data_licenses.md` **before** its first use.
- PII-scrub before any external logging (H9.5). Strip phone numbers, names,
  emails. W&B / Colab logs may persist beyond your session — treat them as
  semi-public.

### Reproducibility

- Set seeds at the top of every notebook: `torch.manual_seed(0)`,
  `np.random.seed(0)`, `random.seed(0)`.
- Pin model revisions: `from_pretrained("google/gemma-...", revision="<commit-hash>")`.
  HF model cards mutate; un-pinned runs from a month ago may not reproduce.
- Save metric tables as CSV under `_results/csv/` for easy diffing across
  runs.

## What does NOT belong here

- iOS / Swift code — that's [../ios/](../ios/).
- Frontend code — that's [../src/](../src/).
- Trained weights — host on the CDN bucket from task H4.
- Raw scam corpora — research-only license; do not commit.
