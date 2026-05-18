# H12 Threshold Sweep Decision

Status: **provisional**

Source artifact: `/home/zenith/workspace/GemScan/notebooks/_results/h12_threshold_sweep.csv`

Selection source: `feasible`

Selected model tier: `E4B`

Selected thresholds:

- `tau_low`: `0.75`
- `tau_high`: `0.95`
- `temperature`: `not regenerated`
- `selected_from_feasible_rows`: `True`
- `feasible_row_count`: `12`

Temperature scaling: not regenerated from predictions because only the sweep CSV was available in the workspace.

H12.1 selection objective:

```text
cost = 1.0 * (true scam -> safe) + 0.2 * (true safe -> scam) + 0.1 * (true safe -> suspicious)
```

Additional diagnostic policy weights beyond the primary H12.1 winner selection objective:

- Scam predicted suspicious: `0.05`
- Suspicious overage above `0.25`: `0.5` per row-equivalent
- Max hard false-positive rate: `0.105`
- Min scam capture rate: `0.85`
- Max suspicious output rate: `0.25`

Held-out rows evaluated: `1255`

## Best Thresholds By Tier

### E2B

- Selection source: `near_miss`
- Feasible row exists for tier: `False`
- `tau_low`: `0.05`
- `tau_high`: `0.95`
- H12.1 cost: `74.1000`
- Diagnostic policy cost: `388.5750`
- Diagnostic policy constraints passed: `False`
- Scam capture rate: `0.9725`
- Scam miss rate: `0.0275`
- Hard false-positive rate: `0.0000`
- Soft false-positive rate: `0.6710`
- Suspicious output rate: `0.7315`
- Decisive output rate: `0.2685`

### E4B

- Selection source: `feasible`
- Feasible row exists for tier: `True`
- `tau_low`: `0.75`
- `tau_high`: `0.95`
- H12.1 cost: `49.5000`
- Diagnostic policy cost: `51.3500`
- Diagnostic policy constraints passed: `True`
- Scam capture rate: `0.9255`
- Scam miss rate: `0.0745`
- Hard false-positive rate: `0.1030`
- Soft false-positive rate: `0.0990`
- Suspicious output rate: `0.1084`
- Decisive output rate: `0.8916`

## Selected Tier Metrics

- Selection source: `feasible`
- H12.1 cost: `49.5000`
- Diagnostic policy cost: `51.3500`
- Diagnostic policy constraints passed: `True`
- False negatives, true scam -> safe: `19`
- Hard false positives, true safe -> scam: `103`
- Soft false positives, true safe -> suspicious: `99`
- Scam miss rate: `0.0745`
- Scam capture rate, true scam -> suspicious/scam: `0.9255`
- Hard false-positive rate: `0.1030`
- Soft false-positive rate: `0.0990`
- Suspicious output rate: `0.1084`
- Decisive output rate: `0.8916`

Confusion matrix labels: `['safe', 'suspicious', 'scam']`

```text
Not regenerated from CSV-only input.
```

Artifacts:

- Sweep CSV: `/home/zenith/workspace/GemScan/notebooks/_results/h12_threshold_sweep.csv`
- Metrics JSON: `/home/zenith/workspace/GemScan/notebooks/_results/h12_best_threshold_metrics.json`
- Runtime constants JSON: `/home/zenith/workspace/GemScan/notebooks/_results/h12_runtime_threshold_constants.json`

Provisional note: this regeneration used the checked-in sweep CSV because the upstream H10 predictions artifact was not available in the workspace. Re-run the notebook against the source predictions to refresh the reliability diagram and confusion matrices.
