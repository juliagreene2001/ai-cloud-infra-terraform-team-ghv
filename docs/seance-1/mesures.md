# TD1 — Mesure initiale du service de scoring

Ali a utilisé Codex sur son poste local pour mesurer la version initiale et conserver les temps par requête.

Le 23 novembre 2026 à 11:11:54 UTC, le benchmark a traité 30 transactions une par une, sans erreur ni expiration de délai. La requête médiane a pris **13,43 ms**. L’enrichissement a pris à lui seul **12,804 ms** en médiane, contre **0,527 ms** pour construire la matrice et **0,098 ms** pour la prédiction. Dans la version mesurée, `client_index` renvoie `None`, donc `enrich` transmet l’historique complet au calcul des agrégats de chaque client. La première modification à tester est un index qui donne directement les lignes du client. [Résumé du benchmark](results.csv) · [30 requêtes individuelles](raw/381f776b.csv)

## Reproduire la mesure

Depuis le dépôt applicatif TD1, utiliser la version initiale (`original` est le nom donné à la mesure, `shipped` est la variante détectée par le benchmark). La commande mesure le calcul en mémoire sur 500 000 lignes d’historique avec 64 variables et un seul thread. Le benchmark effectue un échauffement de 10 transactions avant la répétition mesurée. [Code du benchmark](https://github.com/Guillaume6606/td1-scoring-albertschool/blob/ae2da9da85a4b8a10e63679f5573d2557ac592d5/bench.py)

```sh
td1_output=$(mktemp -d)
uv run --frozen bench.py --mode direct --n 30 --h 500000 --f 64 \
  --batch 1 --nthread 1 --reps 1 --label original --results "$td1_output/results.csv"
```

La mesure porte l’identifiant `381f776b`. Le champ CSV `git_sha` contient l’empreinte du contenu de `features.py`, `scoring.py` et `app.py` (`40f788d0`). L’empreinte du modèle est `22eebcc5`. Seul le champ `host` du résumé a été remplacé par `[redacted]` pour retirer le nom du poste. Dans le fichier des requêtes, `lat` est en secondes et `enrich`, `matrix` et `predict` sont en millisecondes.

## Ce qu’il reste à mesurer

Le débit observé de 68,7 lignes/s décrit cet essai direct. Le benchmark demande au moins 200 requêtes réussies pour interpréter le p95. Pour conclure sur le gain de l’index, il reste à profiler le code puis à comparer les deux versions avec les mêmes paramètres et à vérifier les scores de référence avec `uv run bench.py --check-golden`. Les mesures HTTP sur l’image Docker de l’équipe, dont le pic à 100 requêtes/s, restent nécessaires pour justifier le dimensionnement et le coût dans le notebook.
