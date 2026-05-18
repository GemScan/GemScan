# H10.5 Image Zero-shot Baseline Decision

Status: **official-candidate-reparsed-existing-outputs**

Predictions: `/home/zenith/workspace/GemScan/notebooks/_results/h10_5_image_baseline_predictions.csv`
Reparsed predictions: `/home/zenith/workspace/GemScan/notebooks/_results/h10_5_image_baseline_predictions_reparsed.csv`
Metrics: `/home/zenith/workspace/GemScan/notebooks/_results/h10_5_image_baseline_metrics.csv`
Error audit: `/home/zenith/workspace/GemScan/notebooks/_results/h10_5_image_baseline_error_audit.csv`
Parser schema: `h10_5_image_parser_v2`
Scoring policy: `suspicious` and `spam` predictions are risk-positive; `safe` is risk-negative.

## Overall Metrics

| model_tier | model_id | slice | source_folder | rows | accuracy | risk_macro_f1 | spam_risk_precision | spam_risk_recall | safe_precision | safe_recall | false_positive_rate | false_negative_rate | true_safe | true_spam_or_risk | false_positives | false_negatives | pred_safe | pred_suspicious | pred_spam | avg_output_tokens | parse_ok_rate | min_risk_macro_f1_bar | min_spam_recall_bar | max_false_positive_rate_bar | clears_zero_shot_bar | provisional |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| E4B | google/gemma-4-E4B-it | overall | all | 400 | 0.6175 | 0.6145488899385924 | 0.6424242424242425 | 0.53 | 0.6 | 0.705 | 0.295 | 0.47 | 200 | 200 | 59 | 94 | 235 | 10 | 155 | 49.62 | 0.99 | 0.8 | 0.85 | 0.05 | False | False |
| E2B | google/gemma-4-E2B-it | overall | all | 400 | 0.615 | 0.571078431372549 | 0.5701219512195121 | 0.935 | 0.8194444444444444 | 0.295 | 0.705 | 0.065 | 200 | 200 | 141 | 13 | 72 | 260 | 68 | 52.6725 | 1.0 | 0.8 | 0.85 | 0.05 | False | False |

## Per-source Metrics

| model_tier | model_id | slice | source_folder | rows | accuracy | risk_macro_f1 | spam_risk_precision | spam_risk_recall | safe_precision | safe_recall | false_positive_rate | false_negative_rate | true_safe | true_spam_or_risk | false_positives | false_negatives | pred_safe | pred_suspicious | pred_spam | avg_output_tokens | parse_ok_rate | min_risk_macro_f1_bar | min_spam_recall_bar | max_false_positive_rate_bar | clears_zero_shot_bar | provisional |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| E2B | google/gemma-4-E2B-it | source_folder | personal_image_spam | 200 | 0.935 | 0.48320413436692505 | 1.0 | 0.935 | 0.0 | 0 | 0 | 0.065 | 0 | 200 | 0 | 13 | 13 | 134 | 53 | 52.885 | 1.0 | 0.8 | 0.85 | 0.05 | False | False |
| E4B | google/gemma-4-E4B-it | source_folder | personal_image_ham | 200 | 0.705 | 0.4134897360703812 | 0.0 | 0 | 1.0 | 0.705 | 0.295 | 0 | 200 | 0 | 59 | 0 | 141 | 6 | 53 | 50.53 | 1.0 | 0.8 | 0.85 | 0.05 | False | False |
| E4B | google/gemma-4-E4B-it | source_folder | personal_image_spam | 200 | 0.53 | 0.3464052287581699 | 1.0 | 0.53 | 0.0 | 0 | 0 | 0.47 | 0 | 200 | 0 | 94 | 94 | 4 | 102 | 48.71 | 0.98 | 0.8 | 0.85 | 0.05 | False | False |
| E2B | google/gemma-4-E2B-it | source_folder | personal_image_ham | 200 | 0.295 | 0.2277992277992278 | 0.0 | 0 | 1.0 | 0.295 | 0.705 | 0 | 200 | 0 | 141 | 0 | 59 | 126 | 15 | 52.46 | 1.0 | 0.8 | 0.85 | 0.05 | False | False |

## Decision

Parser v2 repaired the existing raw outputs and selected E4B as the best current tier, but no model clears the configured image zero-shot bars. Treat this as a parser-corrected baseline; rerun H10.5.1 with parser schema v2 for fresh official predictions.
