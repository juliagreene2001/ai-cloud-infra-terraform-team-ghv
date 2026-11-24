# Mesures séance 7 — groupe : team-ghv

Mesures lancées depuis le poste (Windows, Git Bash), aller-retour réseau médian `/health` : 117 ms ; il s'ajoute au premier token (`raw/step0-rtt.txt` : 227, 103 et 117 ms).

Région attribuée : europe-west4 ; rôles pour cette étape (manipulation, mesure, analyse) : Marouane (manipulation, mesure, analyse), seul à bord : les trois rôles sont tenus par la même personne, sans rotation.

## Servir (étape 0)

| Mesure | Valeur |
| --- | --- |
| Démarrage à froid (première requête, jusqu'à la réponse) | 215 s (création Terraform ; la première requête mesurée, 1,075 s, était déjà à chaud) |
| Requête à chaud (même requête, renvoyée juste après) | 1,094 s |
| GPU lu dans la console | 1 × `nvidia-l4` (`nvidia.com/gpu: '1'`, `run.googleapis.com/accelerator: nvidia-l4`), lu avec `gcloud run services describe` |
| Instances au maximum lues dans la console | 1 (`autoscaling.knative.dev/maxScale: '1'`) |
| Concurrence lue dans la console | 16 (`containerConcurrency: 16`) |

Création Terraform : 215 s (3 min 35 s, ligne « google_cloud_run_v2_service.llm: Creation complete after 3m35s » de `raw/step0-apply.txt`). La première requête (1,075 s) est aussi rapide que la seconde (1,094 s) : Cloud Run a démarré l'instance pendant le déploiement et elle répondait encore. Le démarrage à froid est donc la durée de création relevée par Terraform, 215 s, et non la durée de la première requête. Les deux réponses sont `HTTP 200`, avec une phrase dans `choices[0].message.content` (`raw/step0-first.txt`, `raw/step0-warm.txt`, `raw/step0-settings.txt`). Durées lues sur la ligne `real` de `time`, réseau compris.

## Une requête (étape 1)

Médiane de trois mesures par ligne, mesure à froid écartée.

| Prompt (tokens) | Sortie (tokens) | Premier token (ms) | Tokens/s | Durée totale (s) | Contrôle (s) : premier token (ms) ÷ 1 000 + sortie ÷ tokens/s |
| --- | --- | --- | --- | --- | --- |
| 200 | 50 | ... | ... | ... | ... |
| 200 | 200 | ... | ... | ... | ... |
| 1 500 | 50 | ... | ... | ... | ... |
| 1 500 | 200 | ... | ... | ... | ... |

Écart entre la durée mesurée et le contrôle : ... %.

Conclusion : ce qui allonge le délai avant le premier token : ... ; ce qui allonge la durée totale : ...

## Plusieurs requêtes (étape 2)

Prompt de 200 tokens, réponse de 200 tokens. Colonnes de `load.py`.

| concurrence | prompt (tokens) | sortie (tokens) | premier token médian (ms) | premier token max (ms) | tokens/s par requête | durée totale (s) | débit total (tokens/s) | erreurs |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 200 | 200 | ... | ... | ... | ... | ... | ... |
| 4 | 200 | 200 | ... | ... | ... | ... | ... | ... |
| 8 | 200 | 200 | ... | ... | ... | ... | ... | ... |
| 16 | 200 | 200 | ... | ... | ... | ... | ... | ... |
| 32 | 200 | 200 | ... | ... | ... | ... | ... | ... |

Lecture faite pendant le palier à 8 (jamais à 16 : le `curl` serait la 17e requête d'un service à concurrence 16 et attendrait). Créneaux occupés (`/slots`) : ... ; `n_ctx` par créneau lu dans `/slots` : ... tokens ; requêtes en attente (`/metrics`) : ...

Saturation : le débit total ne monte plus à partir de ... requêtes simultanées, à ... tokens/s.

Sort des requêtes au-delà de 16 (palier à 32) : ...

## Tracer (étape 4)

| Étape du span | Durée (ms) | Tokens d'entrée | Tokens de sortie |
| --- | --- | --- | --- |
| `load_context` | ... | - | - |
| `chat <modèle>` | ... | ... | ... |
| `validate_json` | ... | - | - |

Étape la plus lente : ...

Coût d'une alerte, à partir de ses tokens : ... $ (hypothèse de l'étape 3 : 800 tokens en entrée et 150 en sortie ; corrigée en : ...).

## Juger un candidat (étape 5)

Règle écrite avant de lancer le jeu d'évaluation, à ... h ... :

- gain de score minimal exigé : ... point(s)
- perte de débit tolérée : ... %

| Modèle | Score (champs correctement extraits) | Débit (tokens/s) | Mémoire |
| --- | --- | --- | --- |
| 4 bits (notre service) | ... | ... | ... |
| 8 bits (service de l'enseignant) | ... | ... (valeur affichée) | ... (valeur affichée) |

Décision, appliquée à la règle : ...
