# Fiche de dimensionnement du LLM du fil rouge — groupe : team-ghv

Une page. Chaque rubrique cite l'étape dont elle tire ses chiffres.

## Usage et volume (étapes 3 et 4)

Alertes par jour : 87 216 ; tokens d'entrée par alerte : 576 ; tokens de sortie par alerte : 67 (mesurés dans une trace, médiane de cinq alertes ; identifiant de la trace : f17f1c1064187f0ca327c510c54018e9). Le cours supposait 800 et 150 : l'écart réduit le coût de l'API de 53,64 $ à 29,68 $ par jour (`cout.md`).

## Modèle et précision (étape 5)

Modèle retenu : Qwen2.5-7B-Instruct en 4 bits (Q4_K_M). Score qui le justifie : 87,0 % (87 champs sur 100) contre 87,0 % pour le 8 bits : aucun gain, et le 8 bits occupe 8,89 Gio de GPU contre 5,96 Gio. Règle écrite avant (23 h 54, avant tout `eval.py`) : passer en 8 bits seulement avec au moins 5 points de gain et au plus 30 % de perte de débit. Le score est plafonné par le champ `amount` (45 %) dans les deux précisions.

## Performance (étapes 0, 1 et 2)

Démarrage à froid : 215 s (création Terraform d'un service GPU). Délai avant le premier token (prompt de 1 490 tokens) : 639 ms, contre 185 ms pour 208 tokens ; génération à environ 51 tokens/s pour une requête seule. Débit à saturation : 336,4 tokens/s à 16 requêtes simultanées (stable à 32, où le premier token médian passe de 1,6 à 6,0 s).

## Lieu de service et coût (étape 3)

Choix : GPU (un L4 allumé en continu), sous réserve de la marge faible. Coût par jour de l'API : 29,68 $ ; du GPU : 25,12 $ (tokens mesurés ; avec les hypothèses du cours : 53,64 $ contre 25,12 $). Volume de bascule : 73 807 alertes par jour (40 840 avec les hypothèses du cours) : le fil rouge est 18 % au-dessus, l'avantage du GPU est de 4,56 $ par jour.

Débit de sortie requis (alertes par jour × 67 ÷ 86 400) : 67,6 tokens/s (151,4 avec les 150 tokens du cours), contre un débit total mesuré à l'étape 2 de 336,4 tokens/s. Le GPU ne gagne sur le coût que si un seul L4 tient ce débit : oui, avec une capacité d'environ 216 000 alertes par jour en comptant la lecture du prompt.

## Trois nombres à surveiller (étapes 2 et 4)

1. Premier token médian sur un prompt de 200 tokens, seuil : 2,4 s (le double des 1,2 s mesurées à 8 requêtes simultanées).
2. Requêtes en attente (`llamacpp:requests_deferred`), seuil : supérieur à 0 pendant 5 minutes (le service est alors saturé).
3. Tokens par alerte (576 en entrée, 67 en sortie), seuil : plus de 50 % au-dessus de la valeur tracée, soit plus de 864 en entrée ou 100 en sortie (le coût de l'API et le temps de lecture suivent).
