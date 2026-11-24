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
| 208 (demandé : 200) | 50 | 185 | 51,8 | 1,14 | 1,15 |
| 209 (demandé : 200) | 200 | 214 | 51,5 | 4,09 | 4,10 |
| 1 490 (demandé : 1 500) | 50 | 639 | 50,2 | 1,62 | 1,64 |
| 1 490 (demandé : 1 500) | 200 | 659 | 50,4 | 4,61 | 4,63 |

Les prompts sont comptés par le serveur (écart de 4 % et 0,7 % au demandé). Les quatre lignes ont `erreurs` = 0 et `sortie (tokens)` égal à `--max-tokens` (50 ou 200), sans `--ignore-eos`. Aucun essai n'est plus de deux fois plus lent que les deux autres (`raw/step1-p*-m*.txt`). Une requête de chauffe, non notée, a précédé les mesures. Le premier token inclut l'aller-retour réseau du poste (117 ms médian, voir en tête de fichier).

Écart entre la durée mesurée et le contrôle, `(mesurée - contrôle) / mesurée` : -0,9 % (200 / 50), -0,2 % (200 / 200), -0,9 % (1 500 / 50), -0,4 % (1 500 / 200). Le plus grand écart en valeur absolue est 0,93 % (ligne 1 500 / 50 : 1,62 s mesurée contre 1,64 s de contrôle) : la relation durée totale = premier token + sortie ÷ tokens/s tient à moins de 1 %.

Conclusion : ce qui allonge le délai avant le premier token : la longueur du prompt (lecture ou prefill), de 185 ms à 208 tokens à 639 ms à 1 490 tokens, soit environ 454 ms de plus pour 1 282 tokens de prompt en plus, alors que la longueur de la réponse ne change pas le premier token (185 contre 214 ms et 639 contre 659 ms, écarts du bruit de mesure) ; ce qui allonge la durée totale : la longueur de la réponse (décodage), à environ 51 tokens/s quel que soit le prompt : passer de 50 à 200 tokens de sortie ajoute environ 3 s (1,14 à 4,09 s), alors que passer de 208 à 1 490 tokens de prompt n'ajoute que 0,5 s.

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
