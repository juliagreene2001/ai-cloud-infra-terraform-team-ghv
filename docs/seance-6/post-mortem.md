# Post-mortem séance 6 — team-ghv

Un post-mortem sans blâme décrit des mécanismes, pas des personnes : ce que le système a permis, ce
qu'il n'a pas vu, ce qui l'aurait vu plus tôt. Chaque affirmation renvoie à une mesure, un extrait de
log ou une courbe.

Cloud Run a démarré la révision d’incident avec un snapshot vide et un état `/health` `ok`. L’exercice s’est arrêté au déploiement à 0 % à la fin du rejeu.

## 1. Chronologie

| Heure | Événement | Source |
| --- | --- | --- |
| Préparation | Première révision `team-ghv-scorer-next-1120162210` déployée à 0 % à partir du candidat. | Sortie de `release.sh` |
| 17:42:13 CET | Pendant le palier du candidat, 28,0 % d’alertes franchissent la borne de 23,3 %. | `measure.py`, [mesures](mesures.md) |
| 17:56:11 CET | Cloud Run confirme le retour au champion à la suite du palier du candidat. | Sortie de `update-traffic` |
| 18:04:52 CET | Champion à 478 transactions distinctes en trois minutes, 2,7 ms de p95, 0,0 % d’erreurs affiché, 9,2 % d’alertes et 0 s dans la file. | `measure.py` et tableau de bord, [mesures](mesures.md) |
| Après le retour et le retrait du tag `candidate` | `team-ghv-scorer-next-1120174843` est déployée à 0 % à partir du champion. `/health` affiche `status: ok` et `snapshot_rows: 0`. | Sortie de `release.sh` |
| Fin du rejeu | L’exercice d’incident s’arrête à la préparation à 0 %. | Fin du flux de séance signalée par l’équipe |
| Clôture | Retrait du tag `next`. Cloud Run affiche le tag `champion` à 100 % du trafic. | Sortie de `update-traffic --remove-tags=next`, [état final](mesures.md#état-final) |

## 2. Signal

Le signal disponible est le nombre de lignes du snapshot dans `/health`, à **0**, avec `snapshot_error: null`. La mesure à 0 % établit que la révision démarre avec un snapshot vide. Le passage de `next` à 10 % et le relevé par révision sont les preuves manquantes pour chiffrer un délai de détection, un volume affecté et les autres signaux sous trafic.

## 3. Cause

- `release.sh` confirme que la révision d’incident `team-ghv-scorer-next-1120174843` part de `team-ghv-scorer-prep-1119180441`, le champion. La révision reprend le modèle version `1`, le lecteur `snapshot` et le seuil de score de 0,0012. La fiche change le réglage `BQ_DATASET` en `scoring_next`.
- Le `/health` de `next` affiche `snapshot_rows: 0`, `snapshot_error: null` et `status: ok`. La révision démarre avec un snapshot vide. L’effet sur les scores, les décisions et la latence reste à mesurer sur les livraisons de `next` et du champion.
- Champs relevés dans la réponse `/health` de `next`

```text
revision=team-ghv-scorer-next-1120174843
model_version=1  dataset=advanced-cloud-ai.scoring_next
status=ok  snapshot_rows=0  snapshot_error=null
```

## 4. Action qui aurait détecté plus tôt

| Action | Ce qu'elle aurait vu | Quand (étape de la livraison) | Délai gagné | Responsable |
| --- | --- | --- | --- | --- |
| Ajouter au test de mise en service un contrôle du snapshot chargé | `snapshot_rows=0` malgré `status=ok`. Fixer un minimum adapté au jeu de données utilisé. | Appel au `/health` du tag à 0 % | Détection possible avant exposition au trafic. Délai sous trafic indisponible. | Équipe de livraison, responsable à préciser |

**Règle d'alerte retenue** (`google_monitoring_alert_policy.release`, `infra/release.tf`, nom `team-ghv-scorer-release`). Signal : la métrique sur logs `td6_score`, médiane par minute (`ALIGN_PERCENTILE_50`), puis maximum entre séries (`REDUCE_MAX`), une série par révision de `team-ghv-scorer`. Seuil : 0,04, déclenchement au-dessus (`COMPARISON_GT`). Durée : 300 s, cinq minutes consécutives, comme un palier de la livraison. Raison : l'incident `next` est un snapshot vide avec `status: ok` (sections 2 et 3). Le compteur `td6_failed` ne bouge pas, alors que des scores calculés sans les agrégats du client peuvent changer (effet non mesuré, voir la limite 3) : la règle surveille l'effet sur la distribution des scores, pas une erreur. Origine du seuil : lecture de l'API Cloud Monitoring (`timeSeries.list`, lecture seule) pour la révision champion `team-ghv-scorer-prep-1119180441`, 19 et 20 novembre, même aligneur et même réducteur que la règle : 326 points d'une minute avec trafic, médiane entre 0,0250 et 0,0285 (valeur centrale 0,0252). Le seuil de 0,04 laisse une marge de 0,0115 (+40 %) au-dessus du maximum du champion, qui n'a donc jamais franchi le seuil, même sur une seule minute.

Trois limites, à lire avant de compter sur cette règle. 1) Les paliers de `td6_score` sont linéaires, de largeur 0,05 : tant que plus de la moitié des scores est sous 0,05, la médiane lue vaut environ 0,025 divisé par la part de scores sous 0,05. La médiane brute du champion est 0,00017 (1 000 lignes `scored` du 20 novembre, 17:25 à 17:37 UTC), la métrique affiche 0,025. La règle ne s'ouvre donc que si environ 37,5 % des scores dépassent 0,05, contre 0,6 % chez le champion : un décalage plus fin, ou la hausse du taux d'alerte du candidat (28,0 % pour une borne de 23,3 %), ne la déclencherait pas. 2) Elle ne couvre que la hausse des scores. Le sens du décalage d'un snapshot vide n'a pas été mesuré. 3) `next` n'a pas reçu de trafic : aucune série `td6_score` pour cette révision, donc aucun délai gagné à chiffrer. Que la règle aurait détecté `next` reste une hypothèse, à mesurer en l'exposant à 10 %.
