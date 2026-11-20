# Mesures séance 6 — team-ghv

## Valeurs de référence (étape 0)

| Mesure | Valeur |
| --- | --- |
| Heure du relevé ; fenêtre | 20 novembre 2026 à 13:19:01 CET (12:19:01 UTC), sur les 10 minutes précédentes |
| Révision en service (tag `champion`) | `team-ghv-scorer-prep-1119180441` à 100 % du trafic |
| Livraisons et transactions distinctes (`measure.py`) | 6 844 livraisons, 6 279 transactions distinctes scorées |
| Latence applicative p50 et p95 (`measure.py`) | 1,4 ms et 2,6 ms |
| Taux d'erreur (`erreurs`) | 0,0 % à la précision affichée |
| Taux d'alerte (`alertes`) | 11,2 % |
| Âge du plus ancien message non acquitté (tableau de bord) | Maximum observé d’environ 70 s à 13:15 CET sur `team-ghv-live-push` (1,167 min dans l’infobulle) |

Le tableau de bord `TD6 team-ghv` montre un pic bref de l’âge du plus ancien message à 13:15 CET, puis un retour près de zéro. La sortie de `measure.py` décrit les livraisons journalisées par le service sur la fenêtre de référence. La cause du pic reste à établir.

## Critères (étape 1)

Heure à laquelle les critères sont figés : **À RENSEIGNER EN UTC AVANT LE COMMIT**

Objectif de service : au moins 95 % des transactions scorées en 4 ms ou moins de temps de traitement applicatif.

| Signal | Référence | Seuil d'avancement | Seuil de retour arrière | Source |
| --- | --- | --- | --- | --- |
| Latence p95 | 2,6 ms | ≤ 4 ms | > 6 ms | `measure.py`, `p95 ms` |
| Taux d'erreur | 0,0 % affiché | ≤ 0,5 % | > 1 % | `measure.py`, `erreurs` |
| Taux d'alerte | 11,2 % | Écart de ≤ 4 points de pourcentage par rapport au taux attendu | Écart de > 7 points par rapport au taux attendu | `measure.py`, `alertes` |
| Âge du plus ancien message | Proche de 0 s la plupart du temps, pic d’environ 70 s | ≤ 15 s | > 60 s sur deux relevés consécutifs à une minute d’intervalle | tableau de bord |

Avancer si les quatre seuils d’avancement sont respectés. Revenir en arrière si un seuil de retour arrière est franchi selon la durée indiquée. Entre les deux, ou si les mesures sont incomplètes, maintenir le palier et examiner les courbes. Un relevé isolé au-dessus de 60 s exige une vérification du relevé suivant. Cette règle tient compte du pic bref observé à 13:15 CET.

Le taux d’alerte attendu est de 11,2 % au départ. Fixer la valeur attendue pour le candidat à partir des observations en ombre et l’horodater avant le premier palier de trafic réel. Les marges de 4 et 7 points restent fixes.

Borne d'alertes fixée après l'ombre (étape 2) : ... ; écart d'alertes mesuré en ombre : ... points ; heure : ...

Durée d'observation par palier : 5 minutes après confirmation de la répartition du trafic.

Commande de retour arrière (étapes 1 à 3) :

```bash
gcloud run services update-traffic team-ghv-scorer --project advanced-cloud-ai --region europe-west1 \
  --to-revisions=team-ghv-scorer-prep-1119180441=100
```

Commande de retour arrière (à partir du palier à 100 %) ; `champion=100` si vous avez refusé le challenger :

```bash
gcloud run services update-traffic team-ghv-scorer --project advanced-cloud-ai --region europe-west1 \
  --to-tags=candidate=100
```

## Validation (étape 2)

| Mesure | Valeur |
| --- | --- |
| `contrat.ok` ; latence pour 1 000 lignes (champion, candidat) | ... ; ... ms, ... ms |
| AP globale champion, candidat ; écart et `ic95` | ... , ... ; ... [... ; ...] |
| Segment le plus faible ; son écart et son `ic95` | ... ; ... [... ; ...] |
| Segments non concluants | ... |
| `rejeu` : désaccord, taux d'alerte champion et candidat | ... , ... , ... |
| Révision candidate ; version du modèle | ... ; ... |
| Verdict | ... |

## Mesures par palier

Une ligne par palier, relevée à la fin de la durée d'observation. La révision mesurée est la
nouvelle (`candidate`, puis `next` pour la panne, puis `candidate` au retour) ; la révision de
comparaison est celle qui sert de référence au même moment (`champion` jusqu'au palier à 100 %,
`candidate` pour la panne). Chaque case de signal porte deux valeurs : mesurée / comparaison. Au
palier à 100 % et au retour, la révision de comparaison n'a plus de trafic : comparez à la
référence de l'étape 0.

| Palier | Début | Fin | Révision mesurée | Révision de comparaison | `tx distinctes` (mesurée / comparaison) | p95 ms (mesurée / comparaison) | Erreurs (mesurée / comparaison) | Alertes (mesurée / comparaison) | Âge du plus ancien message | Décision | Critère invoqué |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Ombre (0 %) | ... | ... | ... | ... | ... / ... | ... / ... | ... / ... | ... / ... | ... | ... | ... |
| 10 % | ... | ... | ... | ... | ... / ... | ... / ... | ... / ... | ... / ... | ... | ... | ... |
| 50 % | ... | ... | ... | ... | ... / ... | ... / ... | ... / ... | ... / ... | ... | ... | ... |
| 100 % | ... | ... | ... | ... | ... / ... | ... / ... | ... / ... | ... / ... | ... | ... | ... |
| Panne (`next` à 10 %) | ... | ... | ... | ... | ... / ... | ... / ... | ... / ... | ... / ... | ... | ... | ... |
| Retour (`candidate` ou `champion` à 100 %) | ... | ... | ... | ... | ... / ... | ... / ... | ... / ... | ... / ... | ... | ... | ... |

En ombre : désaccord ... % et écart d'alertes ... points (`--compare`), sur ... transactions
communes.

Panne : passage à 10 % à ... ; détection à ... ; délai ... min ; signal : ... (valeur ... , borne ...).

Alias `champion` du registre déplacé sur la version ... à ... .

## Réponses aux questions

### Étape 2 — Validation et ombre

1. Écart global, son intervalle, effet de l'avertissement : ...
2. Segments non concluants, et pourquoi ne pas fonder le verdict sur eux : ...
3. Désaccord en ombre comparé au `desaccord` de la validation, deux raisons d'écart : ...
4. Ce que l'ombre apprend que la validation ne pouvait pas apprendre : ...

### Étape 3 — Paliers

1. Transactions distinctes du candidat à 10 %, et si elles suffisent pour juger son taux d'alerte : ...
2. Signal le plus proche du seuil de retour arrière, et à quel palier : ...
3. Effet de `promote.sh` sur le trafic, et rôle de l'alias du registre : ...

### Étape 4 — Panne

1. Premier signal sorti de sa bande ; signaux qui n'ont pas bougé : ...
2. Signal qui aurait suffi seul ; signal qui ne l'aurait jamais vue : ...
3. Transactions traitées par la révision `next` avant la détection ; ce qu'elle en aurait traité à 100 % : ...
