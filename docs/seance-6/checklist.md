# Checklist de préparation opérationnelle — team-ghv

Une ligne sans preuve est un non. Un non est une réponse recevable : écrivez alors ce qui manque.

| Ligne | Question | Oui / non | Preuve | Ce qui manque |
| --- | --- | --- | --- | --- |
| Validated | Le modèle a-t-il été validé avant de recevoir du trafic, sur des segments et en ombre ? | Oui | Contrat OK dans `team-ghv-validate-mq5p4`. Écart d’AP de +0,0191 sur le segment le plus faible, activité client sur 7 jours ≥ 20. En ombre, 4 798 transactions communes, 7,8 % de désaccord et +5,1 points d’alertes. [Mesures](mesures.md) | |
| Reversible | Peut-on revenir en arrière par une commande écrite d'avance, et l'a-t-on vérifié par la mesure ? | Oui, après le palier à 10 % | Le commit `a7c554d` fixe la commande de retour au champion. Cloud Run confirme son exécution à 16:56:11 UTC après le palier à 10 %. Sur les trois minutes relevées à 17:04:52 UTC, 478 transactions distinctes sur le champion, p95 de 2,7 ms, 0,0 % d’erreurs affiché, 9,2 % d’alertes, 0 s dans la file et 0 livraison réelle sur le candidat. [Critères et mesures](mesures.md) | Le retour propre à l’exercice `next` reste à mesurer. |
| Observed | Voit-on, par révision, les signaux qui disent que le service va mal ? | Non pour l’exercice `next` | Référence champion à 2,6 ms de p95 applicatif. Objectif de 95 % des transactions traitées en 4 ms ou moins. Le signal d’alerte a déclenché le retour du candidat avec 28,0 % mesuré pour une borne de 23,3 %. [Référence et critères](mesures.md) | Un relevé de `next` et du champion sous trafic pour mesurer le signal et confirmer le diagnostic. |
| Degradable | Sait-on ce que fait le service quand la lecture de ses features échoue, et l'a-t-on choisi ? | Non documenté | `/health` montre un snapshot vide pour `next`. [Post-mortem](post-mortem.md) | Comparaison du repli et de la politique de blocage sous trafic. |
| Restorable | Peut-on reconstruire le service à l'identique (modèle, agrégats, configuration) ? | Non documenté | | Plan de restitution Terraform et preuve de reproductibilité du service. |
| Owned | Chaque élément a-t-il un responsable et une politique de réentraînement ? | Non documenté | | Responsables par élément et politique de réentraînement. |
