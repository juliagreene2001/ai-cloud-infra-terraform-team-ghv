# Extensions — team-ghv

Extensions libres réalisées par l'équipe, au-delà du parcours minimum des séances. Pour chacune :
le domaine, ce qui a été fait, où le voir dans le dépôt (fichier et commit), comment le vérifier, et
ses limites.

| # | Domaine | Ce qui a été fait | Fichier et commit | Comment le voir |
| --- | --- | --- | --- | --- |
| 1 | Supervision, Terraform | Règle d'alerte écrite en Terraform et appliquée : `team-ghv-scorer-release`, médiane du score par révision de `team-ghv-scorer` | [`infra/release.tf`](../infra/release.tf), commit `f8f1b9f` ; justification dans [`docs/seance-6/post-mortem.md`](seance-6/post-mortem.md), section 4 | Console : **Monitoring → Alerting**, règle `team-ghv-scorer-release`. En ligne de commande : `python3 scripts/terraform.py plan -target=google_monitoring_alert_policy.release` répond « No changes » |
| 2 | Cycle de vie du modèle | Contrôle de dérive avec décision : trois grandeurs de `fraudfinder.tx_seed` comparées entre la semaine du 10 au 16 septembre et celle du 24 au 30 septembre | [`docs/seance-6/mesures.md`](seance-6/mesures.md), section « Extension — Dérive », données brutes [`docs/seance-6/derive.json`](seance-6/derive.json), commit `45135c6` | Relancer la requête de l'extension « Dérive » de [`docs/seance-6.md`](seance-6.md) dans BigQuery (`europe-west1`) et comparer à `derive.json` |
| 3 | Cycle de vie du modèle | Politique de réentraînement : sur dérive des entrées, justifiée par le délai de sept jours des labels de fraude | [`docs/seance-6/mesures.md`](seance-6/mesures.md), section « Extension — Politique de réentraînement », commit `45135c6` | Lire les cinq lignes de la section |
| 4 | Terraform | Service `team-ghv-scorer`, créé à la main pendant la séance 6, décrit en Terraform par import, dans un dossier à part à état local, avec `prevent_destroy` | [`infra/scorer/`](../infra/scorer/), sortie du plan [`docs/seance-6/plan.txt`](seance-6/plan.txt), commit `45135c6` | `cd infra/scorer && terraform init && terraform plan` : `Plan: 1 to import, 0 to add, 0 to change, 0 to destroy` |
| 5 | Terraform | Garde d'exécution : `scripts/terraform.py` refuse un autre espace de noms, la suppression ou le remplacement du service adopté, et tout type de ressource non relu ; tests en CI sans identifiants | [`scripts/terraform.py`](../scripts/terraform.py), [`tests/test_execution_guards.py`](../tests/test_execution_guards.py), commits `5c32bd1` (création) et `253fe93` (alerte et abonnement d'ombre acceptés) | `pytest tests -q` (24 tests) et `python3 scripts/test_terraform.py` (7 tests Terraform simulés), lancés aussi par [`.github/workflows/test.yml`](../.github/workflows/test.yml) |

## Résultats et limites

**1. Alerte en Terraform.** La règle est active depuis le 24 novembre 2026 (seuil : médiane du score
au-dessus de 0,04 pendant 300 s, par révision). Le seuil vient de la mesure du champion
`team-ghv-scorer-prep-1119180441` : sa médiane est restée entre 0,0250 et 0,0285 sur 326 minutes. Limites :
la métrique `td6_score` range les scores dans des intervalles de 0,05, trop larges pour la médiane réelle
(environ 0,00017) ; la règle ne détecte qu'une hausse forte des scores, et elle n'aurait pas détecté la
hausse du taux d'alerte du candidat (28,0 % pour une borne de 23,3 %). Elle n'a pas été testée sous
trafic, et le projet n'a pas de canal de notification : la règle s'ouvre dans la console, sans envoi.
Un signal plus fin serait le rapport des transactions en alerte (`td6_scored`, `decision`) au total
scoré, par révision.

**2. Dérive.** Montant médian −0,04 %, montant au 95ᵉ centile −0,04 %, transactions par client et par
jour +0,16 %, taux de fraude +37,2 % (de 0,90 % à 1,24 %). Décision : ne pas réentraîner maintenant.
Limite : le taux de fraude de la semaine la plus récente repose sur des labels incomplets (délai de
sept jours), il ne peut pas déclencher seul un réentraînement.

**3. Politique de réentraînement.** Réentraînement sur dérive des trois grandeurs d'entrée, mesurées
chaque semaine sans attendre de label. Limites : le seuil proposé (plus de 10 % d'écart deux semaines de
suite) reste à valider par l'équipe, et rien n'est automatisé.

**4. Service décrit en Terraform.** Le plan d'import ne prévoit aucune modification du service. Limites :
la configuration n'est jamais appliquée (le service appartient au socle) ; le gabarit courant
(`template.revision`) est la révision d'incident `next` à 0 %, pas le champion qui sert 100 % du
trafic, et `plan.txt` le signale en première ligne.

**5. Garde d'exécution.** Les 24 tests et les 7 tests Terraform passent sur `main` au 25 novembre 2026.
Limite : la garde protège les commandes passées par le script, pas un `terraform` lancé directement.
