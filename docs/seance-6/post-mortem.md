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
