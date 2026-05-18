# H9 Image Zero-shot Dataset Report

H10.5 uses this deterministic image corpus for zero-shot multimodal scam/spam image benchmarking.

Corpus: `notebooks/data/processed/h9_image_zero_shot_corpus.csv`
Skipped/corrupt files: `notebooks/data/processed/h9_image_zero_shot_skipped.csv`
Schema version: `h9_image_zero_shot_v1`

## Ground-truth Mapping

- `personal_image_ham` -> `safe`
- `personal_image_spam` -> `spam`
- `spam_archive_jmlr` -> `spam`

## Source/Split Shape

| source_folder | true_label | split | rows |
| --- | --- | --- | --- |
| personal_image_ham | safe | test | 302 |
| personal_image_ham | safe | train | 1404 |
| personal_image_ham | safe | val | 301 |
| personal_image_spam | spam | test | 495 |
| personal_image_spam | spam | train | 2307 |
| personal_image_spam | spam | val | 495 |
| spam_archive_jmlr | spam | test | 1595 |
| spam_archive_jmlr | spam | train | 7440 |
| spam_archive_jmlr | spam | val | 1594 |

## Image Formats

| source_folder | image_format | rows |
| --- | --- | --- |
| personal_image_ham | bmp | 9 |
| personal_image_ham | gif | 614 |
| personal_image_ham | jpeg | 1248 |
| personal_image_ham | png | 133 |
| personal_image_ham | tiff | 3 |
| personal_image_spam | gif | 3167 |
| personal_image_spam | jpeg | 118 |
| personal_image_spam | png | 12 |
| spam_archive_jmlr | bmp | 2 |
| spam_archive_jmlr | gif | 8545 |
| spam_archive_jmlr | jpeg | 2050 |
| spam_archive_jmlr | png | 32 |

## Skipped Files

| source_folder | error_type | rows |
| --- | --- | --- |
| personal_image_ham | UnidentifiedImageError | 14 |
| personal_image_spam | UnidentifiedImageError | 2 |
| spam_archive_jmlr | DecompressionBombError | 5 |
| spam_archive_jmlr | IndexError | 4 |
| spam_archive_jmlr | OSError | 3479 |
| spam_archive_jmlr | UnidentifiedImageError | 1918 |
