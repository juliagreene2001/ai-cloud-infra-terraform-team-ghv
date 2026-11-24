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
| 1 | 209 | 200 | 208 | 208 | 51,8 | 4,05 | 49,3 | 0 |
| 4 | 210 | 200 | 665 | 666 | 23,1 | 9,30 | 86,1 | 0 |
| 8 | 209 | 200 | 1 193 | 1 207 | 25,0 | 9,18 | 174,3 | 0 |
| 16 | 209 | 200 | 1 642 | 2 253 | 25,5 | 9,51 | 336,4 | 0 |
| 32 | 209 | 200 | 5 997 | 11 181 | 24,2 | 19,19 | 333,4 | 0 |

Les cinq paliers ont la même `sortie (tokens)` (200, sans `--ignore-eos`) et `erreurs` = 0 (`raw/step2-c*.txt`). Chaque palier est une seule répétition (`--runs 1`).

Lecture faite pendant le palier à 8 (jamais à 16 : le `curl` serait la 17e requête d'un service à concurrence 16 et attendrait), 2 s après le départ de la charge (écart au mode opératoire, qui attend 5 s : par précaution, pour tomber en plein décodage avant la fin du palier, dont la durée n'était pas encore connue). Créneaux occupés (`/slots`) : 8 occupés sur 16 ; `n_ctx` par créneau lu dans `/slots` : 2 048 tokens (32 768 ÷ 16, comme annoncé) ; requêtes en attente (`/metrics`) : `llamacpp:requests_deferred` = 0, `llamacpp:requests_processing` = 8 (`raw/step2-slots.txt`, `raw/step2-metrics.txt`).

Saturation : règle du plan, recopiée ici : la saturation est le premier palier dont le débit total gagne moins de 10 % sur le palier précédent ; le débit à saturation est le plus haut débit total mesuré. Gains du débit total d'un palier au suivant : 1 à 4 : +75 % (49,3 à 86,1) ; 4 à 8 : +102 % (86,1 à 174,3) ; 8 à 16 : +93 % (174,3 à 336,4) ; 16 à 32 : -0,9 % (336,4 à 333,4). Le premier palier sous 10 % est donc 32 : le débit total ne monte plus au-delà de 16 requêtes simultanées (autant que de créneaux et que la concurrence du service), à 336,4 tokens/s. Débit à saturation (le plus haut mesuré, palier à 16) : 336,4 tokens/s. Le débit par requête, lui, passe de 51,8 tokens/s à 1 requête à 23,1 à 4, puis reste entre 24,2 et 25,5 tokens/s de 8 à 32 : ce n'est pas la capacité du service, la capacité est le débit total.

Sort des requêtes au-delà de 16 (palier à 32) : aucune n'est refusée : 32 réponses `200`, 0 erreur (pas de `429`). Cloud Run les met en file d'attente devant l'instance : les 16 premières sont servies tout de suite (premier token de 1 007 à 2 649 ms, médiane 1 974 ms ; durée de 9,4 à 10,9 s), les 16 autres attendent la fin des premières (premier token de 9 345 à 11 181 ms, médiane 10 640 ms ; durée de 18,1 à 18,9 s, médiane 18,7 s). Le délai d'attente s'ajoute donc au premier token (environ 8,6 s de plus en médiane) sans changer la vitesse de génération de chaque requête (24 à 26 tokens/s) ; la durée du palier double (9,5 s à 16, 19,2 s à 32) pour un débit total inchangé (`raw/step2-c32.txt`).

## Tracer (étape 4)

| Étape du span | Durée (ms) | Tokens d'entrée | Tokens de sortie |
| --- | --- | --- | --- |
| `load_context` | ... | - | - |
| `chat <modèle>` | ... | ... | ... |
| `validate_json` | ... | - | - |

Étape la plus lente : ...

Coût d'une alerte, à partir de ses tokens : ... $ (hypothèse de l'étape 3 : 800 tokens en entrée et 150 en sortie ; corrigée en : ...).

## Juger un candidat (étape 5)

Règle écrite avant de lancer le jeu d'évaluation, à 23 h 54 (heure de la machine, `date '+%H:%M'`, le 24 novembre 2026) :

- gain de score minimal exigé : 5 points (on passe en 8 bits seulement si score 8 bits - score 4 bits >= 5 points de score global)
- perte de débit tolérée : 30 % (on tolère au plus 30 % de perte : 1 - débit 8 bits ÷ débit 4 bits <= 30 %)

Origine de la règle : c'est la règle par défaut proposée par le plan de la séance (gain >= 5 points, perte <= 30 %). Elle a été adoptée en début de session, avant toute mesure du jeu d'évaluation, et consignée ici avant le premier lancement de `eval.py` ; l'horodatage de ce fichier et le commit « docs: TD7 step 5 rule written before evaluation » en font foi. Aucun score n'avait été lu à ce moment : seuls les débits des étapes 1 et 2 étaient mesurés. Le débit à saturation du 4 bits (étape 2) vaut 336,4 tokens/s ; la règle porte sur les deux colonnes du tableau (score et débit), pas sur la mémoire.

| Modèle | Score (champs correctement extraits) | Débit (tokens/s) | Mémoire |
| --- | --- | --- | --- |
| 4 bits (notre service) | 87,0 % (87 champs sur 100, 20 documents, prompt `kyc-extract-v1`) | 336,4 (débit total à saturation, palier à 16, étape 2) | 5,96 Gio sur le GPU (`CUDA0` : poids 4,07 + cache KV 1,75 + tampon de calcul 0,14 Gio), plus 0,29 Gio de poids en mémoire hôte (`CPU_Mapped`) |
| 8 bits (service de l'enseignant) | ... | ... (valeur affichée) | ... (valeur affichée) |

Décision, appliquée à la règle : ...
