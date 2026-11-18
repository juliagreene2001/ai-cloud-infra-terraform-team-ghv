# Changelog


### Added

- Session 5: handout (`docs/seance-5.md`), Cloud Run training/search job scaffold
  (`docs/seance-5/job.tf`), team training account, VPC access to Optuna,
  Vertex AI final-training script (`custom-job.sh`) and report template.
- Session 4: handout (`docs/seance-4.md`), BigQuery subscription, counter SQL,
  feature-store permissions, Qdrant scaffold, `publish_features.py` and
  `kyc_vectors.py`, report template, `history_topic` and `feature_source` variables.
- Squelette Terraform de l'équipe (`infra/`) : backend GCS, variables validées, lecture du socle.
- Énoncé de la séance 2 (`docs/seance-2.md`) : Cloud Run à la main, puis Terraform, puis mesures.
- Séance 3 : énoncé (`docs/seance-3.md`), squelette `docs/seance-3/pubsub.tf` (abonnement push, file de
  messages morts), exemple d'enveloppe, modèle de compte rendu, variable `tx_topic`.

### Changed

- L'identifiant d'équipe peut être un nom choisi (`team-really-cool`, `team-ghv`) : `team` suivi de minuscules, chiffres et tirets, 20 caractères au plus.
- Énoncé de la séance 2 : le service lit `customer_daily.parquet` et `terminal_daily.parquet`
  (FraudFinder) au lieu de `history.parquet`.
