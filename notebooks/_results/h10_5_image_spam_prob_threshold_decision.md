# H10.5 Image Spam Probability Threshold Sweep

Predictions: `/home/zenith/workspace/GemScan/notebooks/_results/h10_5_image_baseline_predictions.csv`
Sweep CSV: `/home/zenith/workspace/GemScan/notebooks/_results/h10_5_image_spam_prob_threshold_sweep.csv`

Threshold rule: predict `spam` when `spam_prob >= threshold`, otherwise `safe`.

## Best Overall Threshold Per Model

| model_tier | threshold | rows | accuracy | macro_f1 | spam_precision | spam_recall | false_positive_rate | false_negative_rate | false_positives | false_negatives | pred_spam | clears_zero_shot_bar |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| E2B | 0.06 | 400 | 0.66 | 0.644314258814 | 0.612676056338 | 0.87 | 0.55 | 0.13 | 110 | 26 | 284 | False |
| E4B | 0.06 | 210 | 0.585714285714 | 0.544740973312 | 0.75 | 0.280373831776 | 0.0970873786408 | 0.719626168224 | 10 | 77 | 40 | False |

## Best Threshold With Spam Recall Target

Target spam recall: `0.85`. This table minimizes false-positive rate among thresholds that meet the target when possible.

| model_tier | threshold | rows | accuracy | macro_f1 | spam_precision | spam_recall | false_positive_rate | false_negative_rate | false_positives | false_negatives | pred_spam | clears_zero_shot_bar |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| E2B | 0.06 | 400 | 0.66 | 0.644314258814 | 0.612676056338 | 0.87 | 0.55 | 0.13 | 110 | 26 | 284 | False |
| E4B | 0.00 | 210 | 0.509523809524 | 0.337539432177 | 0.509523809524 | 1 | 1 | 0 | 103 | 0 | 210 | False |

## Best Per-source Thresholds

| model_tier | threshold | source_folder | rows | accuracy | macro_f1 | spam_precision | spam_recall | false_positive_rate | false_negative_rate | false_positives | false_negatives | pred_spam | clears_zero_shot_bar |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| E2B | 0.96 | personal_image_ham | 200 | 1 | 0.5 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | False |
| E2B | 0.00 | personal_image_spam | 200 | 1 | 0.5 | 1 | 1 | 0 | 0 | 0 | 0 | 200 | False |
| E4B | 0.91 | personal_image_ham | 103 | 0.912621359223 | 0.477157360406 | 0 | 0 | 0.0873786407767 | 0 | 9 | 0 | 9 | False |
| E4B | 0.00 | personal_image_spam | 107 | 1 | 0.5 | 1 | 1 | 0 | 0 | 0 | 0 | 107 | False |

## Notes

- `E2B` rows: `400` by source `{'personal_image_ham': 200, 'personal_image_spam': 200}`.
- `E4B` rows: `210` by source `{'personal_image_ham': 103, 'personal_image_spam': 107}`.
- Model row counts differ, so compare E2B and E4B cautiously until both complete the same eval set.
- No model/threshold pair clears all configured bars. The sweep is still useful for choosing an operating point, but not enough for a passing baseline.
