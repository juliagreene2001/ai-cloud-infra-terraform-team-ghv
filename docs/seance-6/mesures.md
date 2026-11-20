# Mesures séance 6 — team-ghv

Ali (`avakof`) a exécuté la validation, le test en ombre, le palier à 10 %, le retour au champion et la préparation de la révision d’incident, puis a relevé les mesures dans Cloud Shell et Cloud Monitoring.

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

Le relevé préparatoire `date -u` indique le 20 novembre 2026 à **12:37:10 UTC**. Les critères sont enregistrés dans le commit `a7c554d` à **12:39:50 UTC**, avant le déploiement du candidat.

Objectif de service : au moins 95 % des transactions scorées en 4 ms ou moins de temps de traitement applicatif.

| Signal | Référence | Seuil d'avancement | Seuil de retour arrière | Source |
| --- | --- | --- | --- | --- |
| Latence p95 | 2,6 ms | ≤ 4 ms | > 6 ms | `measure.py`, `p95 ms` |
| Taux d'erreur | 0,0 % affiché | ≤ 0,5 % | > 1 % | `measure.py`, `erreurs` |
| Taux d'alerte | 11,2 % | Écart de ≤ 4 points de pourcentage par rapport au taux attendu | Écart de > 7 points par rapport au taux attendu | `measure.py`, `alertes` |
| Âge du plus ancien message | Proche de 0 s la plupart du temps, pic d’environ 70 s | ≤ 15 s | > 60 s sur deux relevés consécutifs à une minute d’intervalle | tableau de bord |

Avancer si les quatre seuils d’avancement sont respectés. Revenir en arrière si un seuil de retour arrière est franchi selon la durée indiquée. Entre les deux, ou si les mesures sont incomplètes, maintenir le palier et examiner les courbes. Un relevé isolé au-dessus de 60 s exige une vérification du relevé suivant. Cette règle tient compte du pic bref observé à 13:15 CET.

Le taux d’alerte attendu est de 11,2 % au départ. Fixer la valeur attendue pour le candidat à partir des observations en ombre et l’horodater avant le premier palier de trafic réel. Les marges de 4 et 7 points restent fixes.

Le 20 novembre 2026 à **13:16:54 UTC**, le taux attendu du candidat est fixé à **16,3 %**. Il additionne le taux de référence de 11,2 % et l’écart mesuré de +5,1 points sur 4 798 transactions communes. La marge d’avancement donne une bande de **12,3 % à 20,3 %**, bornes incluses. Le retour arrière est déclenché par ce signal en dessous de **9,3 %** ou au-dessus de **23,3 %**. Entre ces bandes, prolonger l’observation.

Après le retour au champion, l’exercice `next` conserve le modèle version 1. Les mêmes marges s’appliquent à sa référence de **11,2 %** d’alertes. Les bornes de retour sont donc **4,2 %** et **18,2 %**, avec déclenchement strictement en dehors de cet intervalle.

Durée d'observation par palier : 5 minutes après confirmation de la répartition du trafic.

Commande de retour arrière (étapes 1 à 3) :

```bash
gcloud run services update-traffic team-ghv-scorer --project advanced-cloud-ai --region europe-west1 \
  --to-revisions=team-ghv-scorer-prep-1119180441=100
```

Le champion est la révision saine retenue après le palier à 10 %. La même commande sert pour le retour pendant l’exercice `next`.

## Validation (étape 2)

| Mesure | Valeur |
| --- | --- |
| `contrat.ok` et latence pour 1 000 lignes | `true`, 20 variables dans le même ordre. Champion 5,863 ms, candidat 8,214 ms, sur un échantillon de 20 000 lignes. |
| AP globale et IC à 95 % de l’écart | Champion 0,8473, candidat 0,8823. Écart +0,0350, IC [0,0296 à 0,0397]. |
| Segment le plus faible et IC à 95 % de l’écart | Activité client sur 7 jours ≥ 20. AP de 0,9102 à 0,9293, écart +0,0191, IC [0,0138 à 0,0241], 2 211 fraudes. |
| Segments non concluants | Aucun parmi les six évalués. Le plus petit compte 565 fraudes, au-dessus du minimum de 30. |
| `rejeu`, au seuil de score 0,0012 | Sur 311 624 transactions, désaccord de 7,8835 %. Taux d’alerte de 13,8321 % pour le champion et 14,7951 % pour le candidat, soit +0,9630 point. |
| Révision candidate et modèle | `team-ghv-scorer-candidate-1120124513`, version `2`, artefact `20261118T195729Z8f59f7`. |
| Verdict | Passer au test en ombre à 0 % du trafic réel. Le contrat est compatible et les six segments ont progressé, mais le calcul du candidat prend environ 40 % de temps en plus. Mesurer la latence applicative p95 et les décisions sur le flux en ombre avant de décider du passage à 10 %. |

Mesures issues de la ligne `VALIDATION` de l’exécution `team-ghv-validate-mq5p4` sur août 2026. Les lignes de la sortie Cloud Shell ont été retranscrites dans `validation.txt`. [Transcription](validation.txt) · [Exécution Cloud Run](https://console.cloud.google.com/run/jobs/executions/details/europe-west1/team-ghv-validate-mq5p4?project=advanced-cloud-ai)

La sortie de `release.sh` confirme un déploiement à 0 % du trafic réel. Le `/health` tagué répond `status: ok`, annonce la version `2`, 20 variables et le seuil `0,0012`. Le lecteur `snapshot` a chargé 895 180 lignes avec `snapshot_error: null`. `shadow.sh` a créé l’abonnement `team-ghv-shadow`. Sur la fenêtre mesurée, `measure.py` compte 4 800 livraisons en ombre et zéro livraison réelle pour le candidat.

## Mesures par palier

Les mesures du candidat sont comparées à celles du champion sur la même fenêtre. Pour le retour au champion, les signaux sont comparés aux seuils et au relevé de référence de l’étape 0.

| Palier | Début | Fin | Révision mesurée | Révision de comparaison | `tx distinctes` (mesurée / comparaison) | p95 ms (mesurée / comparaison) | Erreurs (mesurée / comparaison) | Alertes (mesurée / comparaison) | Âge du plus ancien message | Décision | Critère invoqué |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Ombre (0 %) | 13:52 CET | 14:00 CET | `team-ghv-scorer-candidate-1120124513` | `team-ghv-scorer-prep-1119180441` | 4 800 / 4 799 | 2,6 / 2,5 | 0,0 % / 0,0 % | 16,4 % / 11,2 % | 0 s observée sur `team-ghv-live-push` | Autoriser le palier à 10 % dès la reprise du rejeu | p95 de 2,6 ms ≤ 4 ms, erreurs de 0,0 % ≤ 0,5 %, alertes à 0,1 point du taux attendu et âge de 0 s ≤ 15 s. |
| 10 % | 17:31:03 CET | Relevé à 17:42:13 CET | `team-ghv-scorer-candidate-1120124513` | `team-ghv-scorer-prep-1119180441` | 50 / 417 | 2,1 / 2,2 | 0,0 % / 0,0 % | 28,0 % / 11,0 % | 0 s observée sur `team-ghv-live-push` | Retour à 100 % sur le champion confirmé à 17:56:11 CET | 28,0 % d’alertes, soit 11,7 points au-dessus du taux attendu de 16,3 %. Le seuil de retour est de 23,3 %. |
| 50 % | — | — | — | — | — | — | — | — | — | Arrêt du déploiement au palier précédent | Franchissement de la borne d’alertes à 10 %. |
| 100 % | — | — | — | — | — | — | — | — | — | Le champion reprend tout le trafic | Franchissement de la borne d’alertes à 10 %. |
| Retour après le palier à 10 % | 17:56:11 CET | Relevé à 18:04:52 CET | `team-ghv-scorer-prep-1119180441` | Référence de l’étape 0 | 478 sur 3 min | 2,7 / 2,6 | 0,0 % / 0,0 % | 9,2 % / 11,2 % | 0 s | Retour vérifié | Quatre signaux dans leur bande, 0 livraison réelle sur le candidat. |
| Panne (`next`) | — | — | `team-ghv-scorer-next-1120174843` | `team-ghv-scorer-prep-1119180441` | — | — | — | — | — | `next` préparée à 0 % | Fin du rejeu. Impact en trafic à mesurer. |

Sur la fenêtre du 20 novembre 2026 de 12:52 à 13:00 UTC, les logs Cloud Run filtrés par service et par heure ont été analysés avec `measure.py --file`. `--compare` a apparié **4 798 transactions** par `tx_id` et mesuré **7,8 %** de désaccord, avec **+5,1 points** d’alertes pour le candidat. Les taux de 16,4 % et 11,2 % du tableau décrivent toutes les transactions distinctes de chaque révision. L’écart apparié utilise les transactions communes et les taux avant arrondi.

Le graphique `oldest_unacked_message_age` de `team-ghv-live-push` reste à 0 s sur la fenêtre de comparaison, avec une infobulle à 0 s à 13:58 CET. La souscription `team-ghv-live-dead-pull` affiche également 0 message en attente sur la période. [Tableau de bord TD6 team-ghv](https://console.cloud.google.com/monitoring/dashboards/builder/12177969-c25d-4775-921f-8db5cccec810?project=advanced-cloud-ai)

La capture Cloud Run du 20 novembre à 14:13 CET montre le débit agrégé de réponses `2xx` passer d’environ 10 à 20 requêtes/s vers 13:49 CET et revenir près de zéro vers 14:10. Le service atteint 4 instances actives et le p95 HTTP reste proche de 10 ms pendant la période à 20 requêtes/s. Ce doublement de débit est compatible avec une livraison réelle au champion et une copie en ombre au candidat pour chaque transaction. Les mesures par révision et le verdict du palier s’appuient sur les logs applicatifs, en distinguant les livraisons réelles et en ombre. [Métriques Cloud Run](https://console.cloud.google.com/run/detail/europe-west1/team-ghv-scorer/observability/metrics?project=advanced-cloud-ai)

À 16:34 CET, le tableau de bord montre un retour ponctuel du flux, avec 5,65 transactions scorées/s pour le champion et 5,67 pour le candidat, en additionnant les décisions `true` et `false` de l’infobulle. L’âge du plus ancien message dépasse brièvement une minute puis revient près de zéro. La preuve d’un palier réel exige les pourcentages Cloud Run et les logs des livraisons réelles sur cinq minutes. [Tableau de bord TD6 team-ghv](https://console.cloud.google.com/monitoring/dashboards/builder/12177969-c25d-4775-921f-8db5cccec810?project=advanced-cloud-ai)

Vers 16:33 CET, les métriques agrégées de Cloud Run montrent une montée de 0 à environ 6 instances actives, un démarrage de conteneur d’environ 70 à 80 s et un pic de latence de bout en bout de plus d’une minute. Le démarrage à froid pourrait expliquer une partie de l’attente pendant cette reprise. Il faudrait rapprocher les horodatages des logs de démarrage et des requêtes de chaque révision pour confirmer la cause. [Métriques Cloud Run](https://console.cloud.google.com/run/detail/europe-west1/team-ghv-scorer/observability/metrics?project=advanced-cloud-ai)

Lors de la vérification de la colonne « Traffic » après ce relevé, Cloud Run affiche **100 %** pour `team-ghv-scorer-prep-1119180441` et **0 %** pour `team-ghv-scorer-candidate-1120124513`. Les paliers de trafic réel et le retour arrière restent à mesurer sur un flux de transactions. [Historique des révisions du service](https://console.cloud.google.com/run/detail/europe-west1/team-ghv-scorer/revisions?project=advanced-cloud-ai)

Un relevé `measure.py --minutes 5` avant le déploiement de `next` compte 943 transactions réelles distinctes sur le champion, soit environ 3,14/s. Le p95 applicatif est de 2,7 ms, les erreurs de 0,0 % affiché et les alertes de 11,8 %. À ce débit, un palier de cinq minutes à 10 % donnerait environ 94 transactions au candidat. Il faudra s’appuyer sur le nombre effectivement mesuré et prolonger l’observation si le volume est trop faible pour juger le taux d’alerte.

La commande `shadow.sh --off` confirme la suppression de `team-ghv-shadow`. Le 20 novembre 2026 à **16:31:03 UTC**, la sortie de `gcloud run services update-traffic` confirme `champion=90 %`, `candidate=10 %` et `next=0 %`. La fenêtre d’observation de cinq minutes peut se terminer au plus tôt à **16:36:03 UTC**.

Le relevé intermédiaire `measure.py --minutes 5` horodaté à **16:35:21 UTC** comprend environ 42 s avant la confirmation du palier. Il donne 79 transactions distinctes pour le candidat et 1 059 pour le champion, avec des p95 de 2,3 et 2,8 ms et 0,0 % d’erreurs affiché des deux côtés. Le candidat a 11,4 % d’alertes, entre les seuils de retour arrière (9,3 %) et d’avancement (12,3 %) du côté bas. Avec 79 transactions, une décision d’alerte de plus sur le même échantillon change le taux d’environ 1,3 point. Maintenir à 10 % et relever une fenêtre complète de cinq minutes, ainsi que l’âge maximal de la file sur cette fenêtre.

Le relevé `measure.py --minutes 5` à **16:42:13 UTC** couvre environ 16:37:13–16:42:13 UTC, entièrement au palier de 10 %. Il compte 51 livraisons et 50 transactions distinctes pour le candidat, dont 14 alertes. Le champion affiche 418 livraisons, 417 transactions distinctes et 11,0 % d’alertes. Le candidat dépasse la borne de retour de 4,7 points. La règle écrite conduit à rendre le trafic au champion. L’échantillon de 50 transactions ne permet pas d’extrapoler le taux de 28,0 % à un rejeu complet.

Sur cette fenêtre du palier à 10 %, le graphique de `team-ghv-live-push` affiche un âge de 0 s, et `team-ghv-live-dead-pull` affiche 0 message en attente. Le taux d’alerte est le seul des quatre signaux à sortir de la bande d’avancement. [Tableau de bord TD6 team-ghv](https://console.cloud.google.com/monitoring/dashboards/builder/12177969-c25d-4775-921f-8db5cccec810?project=advanced-cloud-ai)

Après ce palier, Cloud Run confirme le 20 novembre 2026 à **16:56:11 UTC** le retour à `champion=100 %`, `candidate=0 %` et `next=0 %`, avec la commande prévue par le commit `a7c554d`. La vérification sur trois minutes de trafic après le retour peut commencer à partir de **16:59:11 UTC**.

Vérification après le retour du palier à 10 %. `measure.py --minutes 3` relevé à **17:04:52 UTC** couvre environ 17:01:52–17:04:52 UTC. Le champion a scoré 478 transactions distinctes sur 479 livraisons, contre 0 livraison réelle pour le candidat. Le p95 du champion est de **2,7 ms** (référence 2,6 ms), les erreurs de **0,0 %** affiché et les alertes de **9,2 %**, à 2 points de la référence de 11,2 % du champion. L’âge maximal observé dans la file sur cette fenêtre est de **0 s**. Les quatre signaux respectent les seuils. Le retour au champion après le palier à 10 % est vérifié. [Tableau de bord TD6 team-ghv](https://console.cloud.google.com/monitoring/dashboards/builder/12177969-c25d-4775-921f-8db5cccec810?project=advanced-cloud-ai)

Le parcours de promotion s’est arrêté au palier à 10 %, conformément au seuil d’alertes. La promotion de l’alias du registre était conditionnée à la validation du palier à 100 %.

L’exercice d’incident s’est arrêté après la préparation à 0 % de `team-ghv-scorer-next-1120174843`. La fin du rejeu empêche de mesurer son effet sur les transactions et le retour qui suivrait ce test. Le contrôle `/health` fournit néanmoins une preuve du snapshot vide. [Post-mortem](post-mortem.md)

## État final

`shadow.sh --off` a supprimé `team-ghv-shadow` avant le passage du candidat à 10 %. Le tag `candidate` a été retiré avant de préparer la dernière révision d’incident. La commande suivante a retiré `next` en fin de séance.

```bash
gcloud run services update-traffic team-ghv-scorer \
  --project=advanced-cloud-ai --region=europe-west1 \
  --remove-tags=next
```

Extrait du retour Cloud Shell confirmant la répartition et les tags après le nettoyage.

```text
Traffic:
  100% team-ghv-scorer-prep-1119180441
       champion: https://champion---team-ghv-scorer-ueiaychpgq-ew.a.run.app
```

## Réponses aux questions

### Étape 2 — Validation et ombre

1. L’AP globale augmente de 0,0350 et l’IC à 95 % [0,0296 à 0,0397] exclut zéro sur ces données. Le candidat a été réglé sur le même mois. Le gain peut donc être surestimé et la décision d’entrée au registre repose sur la lecture de test du TD5.
2. Les six segments sont concluants selon le minimum de 30 fraudes. Sous ce seuil, quelques exemples peuvent faire varier fortement l’AP et donner une estimation trop incertaine pour décider.
3. Les 7,8 % en ombre sont proches des 7,8835 % du rejeu de validation. La proportion des transactions proches du seuil peut varier entre huit minutes de flux et le mois complet d’août. Les valeurs des variables peuvent aussi différer entre les données préparées hors ligne et celles lues par le service dans son snapshot en ligne. Ces deux effets peuvent changer les décisions au même seuil de 0,0012. L’écart apparié d’alertes est passé de +0,963 à +5,1 points sur les fenêtres observées.
4. L’ombre vérifie que le modèle charge ses variables et score des livraisons Pub/Sub dans la révision Cloud Run. Le p95 applicatif du candidat est de 2,6 ms contre 2,5 ms pour le champion, avec 0,0 % d’erreurs affichées sur les deux. La validation mesurait le temps du modèle sur des lots de 1 000 lignes. La comparaison en ombre mesure aussi le changement de décisions pour les mêmes transactions du flux.

### Étape 3 — Paliers

1. Dans la fenêtre complète à 10 %, le candidat a scoré 50 transactions distinctes et levé 14 alertes. Une alerte de plus ou de moins représente 2 points de pourcentage, donc le taux est trop instable pour généraliser. Le seuil écrit suffit pour décider du retour à partir de la fenêtre observée.
2. À 10 %, le taux d’alerte du candidat a franchi la borne de retour de 23,3 % en atteignant 28,0 %. Le p95 de 2,1 ms et le taux d’erreur affiché de 0,0 % sont restés dans leur bande d’avancement.
3. `promote.sh` affecte l’alias Vertex AI `champion` à une version du modèle. Cet alias sert à résoudre la version lors d’un futur déploiement. La répartition entre les révisions Cloud Run se règle avec `gcloud run services update-traffic`.

### Étape 4 — Panne

1. Le premier écart attesté pour `next` est `snapshot_rows=0` dans `/health`, lors du déploiement à 0 %. Les quatre signaux en trafic n’ont pas été mesurés pour cette révision après la fin du rejeu.
2. Un contrôle qui exige un snapshot non vide aurait bloqué cette livraison dès le déploiement à 0 %. Le contrôle limité à `status: ok` a laissé passer le snapshot vide, comme le montre la réponse de `/health`.
3. `next` est restée à 0 % dans le déploiement observé. Sans passage à 10 % ni relevé de transactions de cette révision sur le flux, il manque une base pour estimer un volume affecté à 100 %.
