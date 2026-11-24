# Coût séance 7 — groupe : team-ghv

Les prix sont relus le jour même : le prix de l'API sur la page de tarifs de Vertex AI, le prix horaire du GPU sur la page de tarifs de Cloud Run. Le débit vient de l'étape 2 de `mesures.md` (`raw/step2-c16.txt`) ; les calculs sont refaits par `raw/step3-calc.py` (sortie : `raw/step3-calc.txt`).

## Prix relevés

Prix relevés le 24 novembre 2026 (Relevé : lus sur les deux pages de tarifs, en dollars américains, tarif standard sans remise d'engagement).

| Prix | Valeur | Source et date |
| --- | --- | --- |
| Prix horaire du GPU (L4 sur Cloud Run, région europe-west4) | 1,05 $ / h (1,0465 avant arrondi) | [Tarifs de Cloud Run](https://cloud.google.com/run/pricing), tableau « Services (Instance-based billing) », prix par défaut (USD) du tableau de la région Netherlands (europe-west4), relu le 24 novembre 2026 ; calcul ci-dessous |
| Prix d'entrée de l'API (modèle gemini-3.5-flash-lite) | 0,30 $ par million de tokens | [Tarifs de Vertex AI](https://cloud.google.com/vertex-ai/generative-ai/pricing), onglet « Standard », famille « Gemini 3 », ligne « Gemini 3.5 Flash-Lite », entrée texte, image, vidéo, audio, endpoint global, au plus 200 K tokens d'entrée, relu le 24 novembre 2026 |
| Prix de sortie de l'API | 2,50 $ par million de tokens | Même page, même ligne, « Text output (response and reasoning) », endpoint global, au plus 200 K tokens d'entrée, relu le 24 novembre 2026 |

Choix à confirmer en équipe : l'endpoint retenu est l'endpoint global, qui est la première ligne de chaque modèle. L'endpoint non global (régional) est facturé 10 % plus cher sur la même page : 0,33 $ en entrée et 2,75 $ en sortie par million de tokens. La page n'affiche pas de date de mise à jour : la date retenue est celle de la lecture.

### Prix horaire du GPU

La page de Cloud Run publie un tableau par région. europe-west4 (Netherlands) figure sous « Subject to Tier 1 pricing » (comme us-central1) et son tableau donne les prix unitaires ci-dessous, facturés à la seconde avec la facturation par instance (CPU toujours alloué) :

```text
prix horaire = (prix du GPU par seconde + 4 × prix d'un vCPU par seconde + 16 × prix d'un Gio par seconde) × 3 600
```

| Ressource (instance du service : 1 GPU, 4 vCPU, 16 Gio) | Prix unitaire | Quantité | Par seconde |
| --- | --- | --- | --- |
| GPU NVIDIA L4, sans redondance zonale (« non-zonal redundancy ») | 0,0001867 $ par seconde | 1 | 0,0001867 $ |
| CPU | 0,000018 $ par vCPU-seconde | 4 | 0,000072 $ |
| Mémoire | 0,000002 $ par Gio-seconde | 16 | 0,000032 $ |
| Total | | | 0,0002907 $ par seconde |

Calcul fait avec un court script Python (décimaux exacts) :

```python
from decimal import Decimal as D
gpu_s, vcpu_s, gib_s = D("0.0001867"), D("0.000018"), D("0.000002")
hourly = (gpu_s + 4 * vcpu_s + 16 * gib_s) * 3600   # 1.04652
```

Résultat : 0,0002907 × 3 600 = **1,0465 $ / h, soit 1,05 $ / h** (Dérivé : formule du sujet appliquée aux trois prix relevés).

Vérification : l'estimation du sujet est 1,05 $ / h ; l'écart est de −0,3 %, très en dessous de la tolérance de ±25 % (0,79 à 1,31 $ / h). Il n'y a pas d'écart à expliquer : l'estimation du sujet est arrondie. Pour mémoire, un palier 2 donnerait 1,26 $ / h (+20 %, dans la tolérance aussi), mais europe-west4 est au palier 1.

## Hypothèses du fil rouge

| Hypothèse | Valeur |
| --- | --- |
| Alertes par jour | 87 216 (voir ci-dessous) |
| Tokens d'entrée par alerte | 800 |
| Tokens de sortie par alerte | 150 |
| Débit total à saturation (étape 2) | 336,4 tokens/s (palier à 16 requêtes simultanées ; 333,4 au palier à 32) |

Volume d'alertes : séance 6, 7 268 alertes sur les 72 000 premiers messages du rejeu, soit 10,09 % (Mesuré, seuil 0,0012). À 10 transactions par seconde, une journée compte 864 000 transactions : 864 000 × 7 268 ÷ 72 000 = 87 216 alertes par jour (Dérivé ; hypothèse : le taux du 1er octobre tient toute la journée). Les 800 tokens d'entrée et 150 tokens de sortie par alerte restent l'hypothèse de départ, à corriger avec la mesure de l'étape 4.

## Formules

```text
coût par million de tokens = prix horaire ÷ (tokens par seconde × 3 600 × taux d'occupation) × 1 000 000
coût API par jour          = alertes × (tokens d'entrée × prix d'entrée + tokens de sortie × prix de sortie) ÷ 1 000 000
coût GPU par jour          = prix horaire × 24
volume de bascule          = coût GPU par jour ÷ coût API d'une alerte
débit moyen nécessaire     = alertes × tokens de sortie ÷ 86 400
```

## Les nombres de la preuve (étape 3)

| Nombre | Valeur |
| --- | --- |
| Coût par million de tokens à 100 % d'occupation | 0,86 $ |
| Coût par million de tokens à 20 % d'occupation | 4,32 $ |
| Coût par jour, API | 53,64 $ (87 216 alertes × 800 tokens d'entrée et 150 de sortie) |
| Coût par jour, GPU | 25,12 $ (1,0465 $/h × 24 h, un L4 allumé en continu) |
| Volume de bascule | 40 840 alertes par jour |
| Coût API d'une alerte (formule de la ligne « volume de bascule ») | 0,000615 $ (800 × 0,30 + 150 × 2,50, par million de tokens) |
| Coût GPU par million de tokens de sortie, à comparer au prix de sortie de l'API (mêmes unités : $ par million de tokens) | 0,86 $ contre 2,50 $ (à 100 % d'occupation ; 1,92 $ au taux d'occupation moyen de 45 % calculé plus bas) |

Hypothèses de ces nombres : prix de l'API de l'endpoint global (à confirmer en équipe, voir plus haut), 800 et 150 tokens par alerte (hypothèse du cours, corrigée avec la trace de l'étape 4 plus bas), débit mesuré avec des prompts de 200 tokens, mesures lancées depuis le poste de travail.

## Vérification de capacité

| Mesure | Valeur |
| --- | --- |
| Débit de sortie requis (alertes par jour × 150 ÷ 86 400) | 151,4 tokens/s |
| Débit total mesuré à l'étape 2 | 336,4 tokens/s |
| Un seul L4 suffit au volume ? | Oui en moyenne : le débit mesuré vaut 2,2 fois le débit requis, soit un taux d'occupation moyen de 45 % (151,4 ÷ 336,4). Réserve : mesure faite avec des prompts de 200 tokens (voir question 1) et moyenne sur 24 heures (voir question 2) |

Le GPU ne gagne sur le coût que si un seul L4 tient ce débit : sinon il faut plusieurs instances et le coût par jour du GPU se multiplie.

## Décision

Au volume du fil rouge (87 216 alertes par jour), l'option la moins chère par jour est le GPU : 25,12 $ contre 53,64 $ pour l'API, soit 28,52 $ d'écart par jour (Dérivé). Le volume de bascule est de 40 840 alertes par jour : le fil rouge est au-dessus (2,1 fois), donc le GPU coûte moins cher dès que le volume atteint ce seuil.

Le GPU l'emporte **si** deux conditions tiennent : il coûte moins cher par jour (vérifié : 25,12 $ contre 53,64 $), **et** un seul L4 tient le débit moyen nécessaire (vérifié en moyenne : 151,4 tokens/s requis contre 336,4 mesurés, soit 45 % d'occupation). Si la deuxième condition cessait de tenir (prompts plus longs, pics, volume multiplié par plus de 2), il faudrait un second L4 : le coût du GPU passerait à 50,23 $ par jour, c'est-à-dire presque le prix de l'API (53,64 $), et le gain disparaîtrait. À 20 % d'occupation, le coût par million de tokens (4,32 $) dépasserait le prix de sortie de l'API (2,50 $) : un GPU sous-employé perd son avantage.

Ce raisonnement suppose que le modèle ouvert 4 bits suffit à la tâche : l'étape 5 de `mesures.md` en juge.

## Questions

1. **Prompts de 800 tokens au lieu de 200.** Le débit de l'étape 2 a été mesuré avec des prompts de 209 tokens ; une alerte en compte environ 800. Les tokens d'entrée coûtent du temps de GPU en lecture du prompt (*prefill*) avant le premier token, et ce temps s'ajoute au temps de génération : la capacité réelle d'un L4 en alertes par seconde est donc plus basse que ce que 336,4 tokens/s de sortie laissent croire. Ordre de grandeur (Dérivé, indicatif) : `/metrics` donne 2 876 tokens/s de lecture de prompt pendant le palier à 8 ; 600 tokens de prompt en plus par alerte coûtent environ 0,21 s de GPU, à ajouter aux 0,45 s de génération de 150 tokens (150 ÷ 336,4). Soit environ 0,66 s par alerte, 1,5 alerte par seconde ou 132 000 alertes par jour : au-dessus des 87 216 du fil rouge, avec un taux d'occupation moyen d'environ 66 % et non 45 %. Un seul L4 tient encore, mais avec moins de marge. La trace de l'étape 4 mesure les vraies longueurs.
2. **Le débit requis est une moyenne sur 24 heures.** Les alertes n'arrivent pas à cadence constante : aux heures de pointe, le débit requis dépasse la moyenne de 151,4 tokens/s (la capacité mesurée est de 336,4 tokens/s au plus), et les requêtes en excès attendent : au palier à 32 requêtes simultanées (le double des 16 que le service accepte à la fois), le débit total ne monte plus (333,4 tokens/s) et le premier token médian passe de 1,6 s à 6,0 s (maximum 11,2 s), alors qu'aucune requête n'échoue. Si un pic dépasse la capacité de façon prolongée, la comparaison tourne : il faut une seconde instance, ou accepter une latence qui monte. Un pic de deux fois la moyenne (303 tokens/s) tient encore sur un L4, à 90 % d'occupation.
