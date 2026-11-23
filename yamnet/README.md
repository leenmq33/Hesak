# YAMNet sound detection (Hesak)

Final version: **head v11**, tested in **Round 5** (96 new clips, run once).

## How it works

- **YAMNet** (frozen, from TF Hub `https://tfhub.dev/google/yamnet/1`) turns 16 kHz audio into class scores and a 1024-d embedding per frame.
- A small **head** trained by the team (`hesak_head_v11.keras`) classifies the embeddings.
- For each sound, `hesak_head_v11_config.json` sets the threshold and the decision mode: YAMNet class scores only (`mapping`), the head only (`head`), or both (`head_and_mapping` / `head_or_mapping`).
- `hesak_labels.json` (v2.0) is the list of the **16 sounds** shown to the user. It is built on `hesak_labels_v1.9.json` (YAMNet class mapping and suppress rules).

## Round 5 result (v11)

| Target | Required | Result |
|---|---|---|
| Critical detection (siren, alarm) | ≥ 80% | 100% |
| Important detection (knock, bell, scream) | ≥ 75% | 80% |
| Mean detection | ≥ 70% | 88.75% |
| False alarms on other sounds | ≤ 20% | 18.75% |

Weakest sounds: washing machine 40%, knock 60%, rain 60%.

## Files

| Path | Content |
|---|---|
| `notebooks/hesak_step16_train_head_v11.ipynb` | Trains head v11 and tunes the thresholds |
| `notebooks/hesak_step17_test_round5.ipynb` | Final test (Round 5), with outputs |
| `model/hesak_head_v11.keras` | Trained head |
| `model/hesak_head_v11_config.json` | Thresholds and decision mode per sound |
| `model/hesak_labels.json` | Displayed sounds (v2.0) |
| `model/hesak_labels_v1.9.json` | Internal labels used by v2.0 |
| `results/step17_round5_summary.json` | Round 5 summary |
| `results/step17_round5_per_sound.csv` | Round 5 result per sound |
| `results/step5v11_training_curves.png` | Training loss and validation mAP |

Audio data is not included. The notebooks read it from the team's Google Drive.
