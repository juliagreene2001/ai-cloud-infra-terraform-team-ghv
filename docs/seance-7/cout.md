# Coût séance 7 — groupe : ...

Les prix restent vides : le prix de l'API est relu sur la page de tarifs le jour même, le prix horaire du GPU sur la page de tarifs de Cloud Run.

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
| Débit total à saturation (étape 2) | ... tokens/s |

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
| Coût par million de tokens à 100 % d'occupation | ... $ |
| Coût par million de tokens à 20 % d'occupation | ... $ |
| Coût par jour, API | ... $ |
| Coût par jour, GPU | ... $ |
| Volume de bascule | ... alertes par jour |
| Coût API d'une alerte (formule de la ligne « volume de bascule ») | ... $ |
| Coût GPU par million de tokens de sortie, à comparer au prix de sortie de l'API (mêmes unités : $ par million de tokens) | ... $ contre ... $ |

## Vérification de capacité

| Mesure | Valeur |
| --- | --- |
| Débit de sortie requis (alertes par jour × 150 ÷ 86 400) | ... tokens/s |
| Débit total mesuré à l'étape 2 | ... tokens/s |
| Un seul L4 suffit au volume ? | ... |

Le GPU ne gagne sur le coût que si un seul L4 tient ce débit : sinon il faut plusieurs instances et le coût par jour du GPU se multiplie.
