# Discussion avec le professeur Prendinger — notes et résultats du test original

Préparation : 22 octobre 2026 ; résultats mis à jour le 29 octobre. Présentation en anglais, notes de préparation en français.

## La proposition

Les deux PDF utilisent désormais le **moteur cash-MTM du papier**, avec les mêmes 48 fits AutoGluon, Kumo, TabPFN et Random Forest. Entrées Test : **2026-01-08–2026-07-18** ; dernières sorties et valorisation : **2026-07-25**. Cela donne 199 barres et **28 rendements hebdomadaires**.

**M1 est reproduit dans les 48 cellules** : UP, rendement −43,3134 %, Sharpe −2,0372 ; DOWN, rendement +12,8333 %, Sharpe +0,7622. Les 40 CSV journaliers sont identiques à GPU8. L'écart précédent provenait du moteur spread et du calendrier tronqué à la dernière entrée, pas des propositions de M1. Les lignes de `roi_ext_mtm.csv` et leurs fichiers sources sont dans `pilot_results/paper_mtm_20261029/`.

**Le TBM étiquette les propositions de M1 pour entraîner M2.** Kronos et ses prévisions restent figés. TP signifie true-positive meta-labeling, pas take profit : label 1 si le rendement signé au jour 7 dépasse les frais de 0,2 %. TB ref garde ce label sur les mêmes exemples éligibles que TB-k ; TB-k utilise l'issue profit/stop/expiration. Les backtests financiers de toutes les colonnes gardent des sorties à J+7.

Les slides 13–15 montrent les 48 Sharpes MTM et les deux deltas recalculés. **Tous les Sharpes UP restent négatifs.** Le plus haut DOWN observé est TabPFN k=1 : **1,1614**, soit **+0,3722 contre TP** et **+0,4188 contre TB ref**. Rendement +14,0486 %, drawdown −13,0613 %. Son Sharpe dépasse M1 DOWN (0,7622), sans constituer une preuve statistique de supériorité.

RF UP k=1,5 : Sharpe **−0,8393**, gain **+0,2661 contre TP**, **+0,0897 contre TB ref** ; rendement toujours négatif, **−18,1501 %**. AutoGluon DOWN k=1,5 gagne +0,8609 contre TP mais seulement +0,0395 contre TB ref. Les conclusions du précédent calcul spread ne doivent pas être réutilisées.

Les M2 sont de nouveaux fits : leurs probabilités et leurs décisions diffèrent des modèles sauvegardés du papier, même dans TP. Chaque delta compare le nouveau fit à son propre TP ou TB ref. Le moteur cash utilise aussi les probabilités de M2 pour la taille des positions ; le delta reflète donc le modèle complet avec cette règle de taille fixe.

Les 77 propositions TON retirées de l'entraînement (13 UP, 64 DOWN) expliquent pourquoi le delta contre TP inclut aussi un effet d'éligibilité. Trois cellules conservent le seuil de secours 0,5 : AutoGluon UP TB ref et k=1, TabPFN UP k=0,5. La correction séparée de la référence de précision sur validation n'a pas été appliquée ici : aucun seuil ni modèle n'a été modifié par le replay MTM.

TabPFN et RF conservent les paramètres HPO_NoCal de Pablo, figés par direction entre targets. RF : 100 arbres / profondeur 3 UP, 900 / profondeur 12 DOWN. TabPFN : 4 estimateurs UP, 32 DOWN. Les deux vagues de 24 fits sont terminées ; la mise à jour des slides ne les réentraîne pas.

Les contrôles vérifient 280 lignes du tableau du papier, rejouent 150 métriques pour ses 10 cellules Kronos 1d, puis les 48 cellules de notre expérience. Toutes les positions sont clôturées. Les rendements finaux cash au coût d'entrée et MTM concordent. Une exécution par cellule et un Test déjà inspecté : comparaison exploratoire, sans sélection d'un k optimal ni preuve de significativité.

## Périmètre exact et reproductibilité

Cette présentation utilise les lignes du fichier real/1d.parquet correspondant aux 20 actifs déjà couverts par les prévisions Kronos de SecondaryModel (et non la colonne fit20, qui est la cohorte de calibration du modèle de régime de Synthetic-Generation, sans rapport avec la couverture Kronos — seuls 13 des 20 actifs se recoupent), avec period = train, embargo = False, pred_class dans UP/DOWN et kronos_valid = True.

- 19 des 20 actifs sources ; TON est absent du parquet de ces diagnostics.
- 7 593 propositions éligibles : 1 921 UP et 5 672 DOWN.
- Aucune ligne perdue au filtre de 120 observations d'historique pour la volatilité.
- Période d'entraînement définie par le projet : juillet 2024 à août 2025 ; les événements traversant la frontière de période sont exclus.
- Aucun résultat de validation ou de test n'entre dans les graphiques ou la sélection de l'exemple.
- Aucun M2 n'a été entraîné par ce script.
- Les 254 952 événements du précédent benchmark étaient répartis sur 441 actifs. Ce n'était pas un résultat limité à ces 20 actifs.
- Un benchmark LightGBM réentraînant M2 par target existe déjà sur ce périmètre plus large. Il est exploratoire et ne remplace pas le test ciblé présenté ici.

Les 20 actifs sont AAVE, ADA, AVAX, BCH, BNB, BTC, DOGE, DOT, ETH, HBAR, LINK, LTC, NEAR, SHIB, SOL, SUI, TON, TRX, XLM et XRP, tous cotés contre USDT — l'univers propre de SecondaryModel. TON est absent du fichier real/1d.parquet de Synthetic-Generation (aucune orthographe alternative trouvée) ; les mesures ci-dessous portent donc sur 19 des 20 actifs. Cela n'affecte pas le futur pilot M2, qui lira directement les CSV de SecondaryModel (où TON est présent) plutôt que ce parquet.

Calculs : daily-return EWMA span 100, volatilité connue au close d'entrée, largeur k·σ·√7, barrières symétriques fixées pour chaque événement, high/low des 7 bougies suivantes, coût total 0,2 %. Les deux barrières touchées dans la même bougie sont comptées comme un stop. Les fills à la barrière sont une simplification.

Les rendements à J+7 recalculés depuis les bougies sont vérifiés contre ret_7, et les labels actuels contre 1[s·ret_7 > 0,002].

## Slide 1 — Une question reliée à la thèse

« My thesis asks whether synthetic data can improve M2. Before augmenting its training set, I want to make sure that its target represents the trade we actually want to evaluate. »

C'est une vérification de la définition de succès de M2, et non une promesse que TBM améliore les performances.

## Slide 6 — Faut-il réentraîner M2 ?

Trois opérations différentes :

| Opération | Nouvel entraînement ? |
|---|---|
| Mesurer σ, poser des barrières, recalculer les labels | Non |
| Évaluer d'autres sorties avec les mêmes signaux/scores existants | Non, mais cela teste les sorties |
| Apprendre à prédire le nouveau meta-label | Oui pour M2 ; pas pour M1 |

Les targets historiques se calculent en regardant les futurs réalisés. Les features de M2 restent celles disponibles à l'entrée.

Avec le recipe actuel, les modèles long et short sont séparés. Deux versions de target impliquent donc quatre modèles par seed pour un k fixé : baseline UP/DOWN et TB UP/DOWN. Si l'on choisit un modèle partagé avec la direction en feature, le compte change. Il ne faut pas confondre cette organisation de M2 avec le nombre de k.

Pour une recherche complète de k, chaque candidat change le target : il faut donc aussi ajuster M2 pour ce target sur l'entraînement. Les prédictions de M1 sont réutilisables si les événements et features restent inchangés.

## Slide 7 — Bougies habituelles et application aux deux directions

Exemple réel BTC, entrée au close du 3 juillet 2024, signal Kronos UP. L'exemple a été sélectionné dans l'entraînement parce qu'il illustre clairement un stop avant l'expiration, sans ambiguïté de double touche.

Largeur k = 1 : environ 6,44 %. Le prix est normalisé à 100 à l'entrée.

- Long : barrière basse = stop ; sortie jour 2 ; net environ −6,64 % ; label 0.
- Short au même point, présenté uniquement comme illustration contrefactuelle : barrière basse = profit ; net environ +6,24 % ; label 1.

Le panneau short n'est pas une deuxième prédiction réelle de Kronos.

Une même date et un même actif donnent la même volatilité pour les deux côtés. On applique les seuils au rendement de la position s(P/P₀−1), où s vaut +1 ou −1. Avec des distances symétriques, les prix des barrières sont les mêmes et leurs rôles s'inversent. Avec des distances profit/stop asymétriques, les niveaux et la sortie peuvent changer en inversant le côté.

Les bougies futures créent le label. Elles ne deviennent pas des inputs de M2.

## Slide 8 — Volatilité par actif et dans le temps

Le paramètre recommandé pour commencer est un k global, mais la largeur est w(a,t) = k·σ(a,t)·√7.

La figure montre, pour chacun des 20 actifs, la médiane de σ quotidienne aux dates d'entrée, et son intervalle de percentiles 10–90 au fil de ces dates. Cet intervalle décrit la variation de volatilité ; ce n'est pas un intervalle de confiance.

| Actif | σ quotidienne médiane | Largeur médiane à k = 1, h = 7 |
|---|---:|---:|
| BTC | 2,53 % | 6,71 % |
| ETH | 3,62 % | 9,59 % |
| SUI | 6,17 % | 16,32 % |

Cela montre pourquoi un même pourcentage fixe ne représente pas la même distance relative aux fluctuations habituelles.

Un k global ne signifie donc pas des barrières identiques pour les 20 actifs. La largeur change aussi au cours du temps pour un même actif, mais reste fixe une fois l'événement ouvert.

La règle √7 est une approximation de mise à l'échelle de variance, pas un résultat exact ni une obligation de TBM. Normaliser par σ ne garantit pas des risques de queue identiques.

## Slide 9 — Différences UP/DOWN

Mesures à k = 1 sur les propositions réelles, pondérées par événement à l'intérieur de chaque direction :

| Direction | N | Positifs actuels | Positifs TB | Labels modifiés |
|---|---:|---:|---:|---:|
| UP | 1 921 | 50,7 % | 49,6 % | 5,9 % |
| DOWN | 5 672 | 49,2 % | 48,9 % | 4,4 % |

Les sorties sont proches ici : environ 25–27 % de profits, 28–32 % de stops et 44–45 % d'expirations.

Le graphique compare désormais **sans TB** (toutes les propositions sortent à J+7)
et **TB à k=1**, en séparant les expirations positives et négatives après 0,2 %
de frais. Chaque pourcentage porte sur toutes les propositions de la direction,
pas uniquement sur celles qui expirent. Les deux panneaux utilisent les mêmes entrées.

| Direction | Sans TB : positif / négatif | TB : profit / stop | TB : expiration positive / négative |
|---|---|---|---|
| UP | 50,7 % / 49,3 % (974 / 947) | 27,0 % / 28,0 % (518 / 537) | 22,6 % / 22,5 % (434 / 432) |
| DOWN | 49,2 % / 50,8 % (2 788 / 2 884) | 24,7 % / 31,5 % (1 400 / 1 787) | 24,2 % / 19,6 % (1 375 / 1 110) |

Au sein des seules expirations TB, 50,1 % sont positives en UP et 55,3 % en DOWN.
Aucun rendement net n'est exactement nul dans ces groupes. Les calculs vérifient
que les rendements TB à expiration égalent ceux à J+7 sans TB pour les mêmes entrées,
et que chaque répartition contient exactement toutes les propositions.

Les proportions de labels positifs ne sont pas l'accuracy de M2 : M2 n'intervient pas dans cette mesure. Les groupes UP et DOWN ne contiennent pas les mêmes dates ni les mêmes conditions de marché ; cette comparaison ne prouve pas qu'un côté exige une autre estimation de σ ou un autre k.

Le fichier brief_fit20_asset_direction.csv fournit aussi la ventilation par actif, direction et k. Examiner les effectifs avant d'interpréter une petite sous-population. On ne compte qu'une double touche à k = 1 dans ce périmètre.

## Slide 10 — Ce que montre la grille de k

Chaque actif a le même poids dans ces deux courbes :

| k | Sorties horizontales moyennes | Labels modifiés moyens |
|---|---:|---:|
| 0,5 | 93,2 % | 23,0 % |
| 1 | 55,8 % | 4,8 % |
| 1,5 | 26,8 % | 0,9 % |
| 2 | 13,6 % | 0,2 % |

Le ruban décrit les percentiles 10–90 entre actifs. Ce n'est pas une incertitude statistique sur la moyenne.

Le point à faire passer : « A similar binary label can hide a different trade. » Deux trades peuvent rester tous les deux gagnants tout en ayant des gains et durées très différents. Le faible pourcentage de flips ne suffit donc pas à conclure que les barrières ne changent rien.

“Horizontal exit” inclut une touche pendant la dernière bougie ; ce n'est pas nécessairement une sortie strictement avant le jour 7.

Ces courbes caractérisent le target. Elles ne mesurent pas la performance d'un M2 et ne permettent pas, seules, de choisir le meilleur k.

## Slide 11 — Comment choisir k ?

Recommandation : un k partagé entre actifs et directions pour le premier test. La volatilité réalise déjà une adaptation par actif et par date. Vingt k individuels, puis deux directions, ajoutent beaucoup de choix à estimer avec peu de données par sous-groupe.

Procédure proposée :

1. Définir le trade exécuté et ses contraintes. Si des stops sont déjà imposés, reproduire cette politique avant de chercher arbitrairement un k.
2. Fixer h = 7 et l'estimateur de σ ; limiter les candidats, par exemple 0,5 / 1 / 1,5 / 2.
3. Entraîner les M2 candidats sur train, sans faire entrer leurs futurs de validation.
4. Choisir k et les règles de sélection sur validation uniquement, selon un objectif de portefeuille net préannoncé. Si l'objectif est le Sharpe, vérifier aussi drawdown, frais, turnover et couverture, plutôt que retenir un pic isolé.
5. Examiner la stabilité temporelle et les résultats par actif/direction. Pour les diagnostics transversaux, donner le même poids aux actifs ; ne pas présenter une moyenne de Sharpes individuels comme le Sharpe d'un portefeuille.
6. Figer la configuration et la confirmer sur une période réellement non utilisée. Les résultats 2026 précédents ont déjà été inspectés ; ils ne constituent plus une confirmation entièrement nouvelle pour un choix inspiré par ces résultats.

Pour aller au-delà d'un split unique, utiliser une validation chronologique ou walk-forward avec suppression des événements dont les horizons chevauchent les blocs évalués. Les événements sur plusieurs actifs partagent des dates et des facteurs de marché ; ils ne sont pas des observations indépendantes.

Un k par direction, par groupe d'actifs ou par actif ne vient qu'après une amélioration stable hors des données utilisées pour choisir la spécialisation. Il n'y a pas d'« idéal » universel. Obtenir 50 % de labels positifs n'est pas un objectif économique.

Références : AFML §§3.3–3.7, ch. 7 et ch. 11 ; [travaux de López de Prado sur le backtest overfitting](https://www.quantresearch.org/Publications.htm).

## Slides 2–5 — Dates, M1 et méthode du papier

La slide 2 garde trois lignes : train, validation, Test. Le Test désigne les entrées ; une ligne de bas de page précise les dernières sorties au 25 juillet. Les dates effectives train et validation restent celles du loader original de Pablo.

La slide 3 affiche le M1 cash-MTM reproduit : −2,0372 UP, +0,7622 DOWN. La slide 4 distingue la perte finale du drawdown : après liquidation complète, le rendement UP est −43,31 % avec ou sans MTM ; le drawdown est −45,35 % au coût d'entrée et −48,75 % en MTM. MTM change la trajectoire de valorisation, donc le risque mesuré.

La slide 5 reprend les valeurs cash-MTM du papier pour RF, AutoGluon, CTTS, TabPFN et TabICL. Le M1 est commun ; les M2 du papier et nos M2 réentraînés sont distincts. La matrice finale utilise exclusivement nos nouveaux fits, avec le même moteur et le même calendrier de sortie que le papier.

Reconstruction : `analysis/reconcile_paper_mtm.py`, puis `analysis/prepare_mtm_slides.py`. Les nombres affichés et les deltas proviennent de `pilot_results/paper_mtm_20261029/slide_data.json`. Le script de reconstruction des slides n'applique pas la correction de seuil isolée sur `fix/threshold-validation-cohort`.

## Archive — ancien essai 2025-10-09–2026-01-18

La matrice exécutée croise **deux backends** (AutoGluon, Kumo), **six targets** (TP original, TB ref, k = 0,5 / 1 / 1,5 / 2) et **deux directions** : 24 fits. Chaque backend possède sa propre baseline TP. L'exécution reste à J+7 dans toutes les cellules ; nous ne testons pas encore des sorties TB ni l'augmentation synthétique.

Le lancement appelle le vrai `m2_pipeline.py --phase training`. Les splits, features, coûts de 0,2 %, horizon 7 et méthode `utility_nocal` viennent de la configuration demandée. `val_backtest: false` : un modèle de production entraîné sur la fenêtre complète par cellule, puis le Test original. Les rendements et trades M1 Test doivent rester identiques. La vérification a aussi détecté une différence d'éligibilité à l'entraînement : le warmup de 120 jours exclut 77 propositions TON (13 UP, 64 DOWN), présentes dans TP mais absentes de TB ref et de tous les k. Le contrôle TB ref conserve les labels TP sur exactement le même sous-ensemble que les cibles TB. Ce n'est donc pas un simple aller-retour bit-identique de TP.

- Entraînement configuré : 1 juillet 2024 – 30 mai 2025.
- Fin de validation : 1 octobre 2025 ; fin des données configurée : 25 janvier 2026.
- Trades Test effectivement observés après embargo et disponibilité des horizons : **9 octobre 2025 – 18 janvier 2026**.
- Univers source : les 40 CSV UP/DOWN des 20 actifs de SecondaryModel, incluant TON. Les diagnostics précédents reposent sur 19 actifs et un autre découpage temporel ; ils ne définissent pas la baseline financière de ce test.
- AutoGluon : `best_quality`, budget original de 3 600 secondes par direction. Les logs signalent des composants optionnels absents (LightGBM, CatBoost, fastai, Ray) ; toutes ses cellules partagent cet environnement. Ne pas présenter ce run comme une reproduction exacte d'un ancien run `tabarena`.
- Kumo : défaut existant `large`, seed 42 ; M1 reste figé.

La table TP vérifie d'abord le point de comparaison : **M1 UP = Sharpe 0,5625, rendement +1,8003 %**, soit la baseline du dépôt. Les gains short élevés concernent d'autres propositions et un marché favorable à cette direction. Ils ne sont pas une amélioration due au TB.

La matrice montre le Sharpe Test de chaque cellule et sa différence par rapport à **TB ref du même backend et de la même direction** : c'est le contraste qui isole les labels. La table conserve aussi les différences par rapport au TP original, mais celles-ci incluent l'effet du filtre d'éligibilité. Le train passe de 1 775 à 1 762 exemples UP, et de 4 545 à 4 481 DOWN ; aucune ligne Test n'est perdue. Un Δ positif ne constitue ni un test de significativité ni une confirmation indépendante du meilleur k. Les métriques détaillées incluent rendement, drawdown, couverture, seuil et `constraint_satisfied` ; un indicateur faux signale que les conditions de sélection ne sont pas toutes satisfaites, avec éventuellement le seuil de repli de la pipeline.

**Résultats complets au 27 octobre 2026 : 24/24 fits et rapport terminés avec succès.** Avec Kumo, k = 1 passe de 1,291 à 2,182 en UP et de 4,129 à 4,956 en DOWN par rapport à TB ref. En DOWN, il reste sous le TP original (5,353) et son rendement baisse de 104,21 % à 77,77 % par rapport à TB ref. Avec AutoGluon, k = 2 passe de 0,712 à 1,184 en UP et de 5,507 à 6,353 en DOWN ; ce dernier gain de Sharpe s'accompagne lui aussi d'un rendement inférieur au contrôle (131,98 % à 113,04 %). k = 0,5 dégrade fortement le DOWN pour les deux backends. La conclusion présentable est donc une amélioration du Sharpe pour certains couples backend/k sur cette fenêtre, pas une amélioration universelle du TB ni un k optimal confirmé.

## Archive — Sharpe de cet ancien essai

Le moteur original est conservé : il étale les rendements des trades sur sept barres, normalise par la concentration moyenne, puis compose la courbe. Le Test couvre 102 barres et **14 rendements non chevauchants de sept jours** ; le Sharpe est annualisé par √(365,25/7). Ce sont des statistiques de ce backtest sur une fenêtre courte, pas des performances annuelles réalisées ni un audit validant le moteur d'exécution.

Ne pas choisir k sur ce Test puis qualifier ce même résultat de confirmation indépendante. Toute nouvelle sélection demande une nouvelle période réellement non utilisée ou un protocole chronologique fixé à l'avance.

## Ancien graphique de validation : retiré

Le premier essai choisissait le seuil et mesurait sa performance sur Val-Cal + Val-Opt : circulaire. Le correctif découpait ensuite une tranche Feb–May 2025 dans la queue de l'entraînement et ajustait un second modèle sur un train réduit. Cette tranche était disjointe, **mais le seuil restait optimisé sur des dates ultérieures (Jun–Oct 2025)**. Elle ne représentait donc pas une évaluation chronologique autonome.

Le graphique ancien fondé sur `pilot_results/selection.csv`, avec M1 UP = 4,03, est conservé comme archive et n'est plus présenté. Ses conclusions « aucun mode ne bat M1 » et « k = 0,5 est le pire » ne sont pas transférées au Test original. Le Test a été inspecté ; on ne le présente plus comme scellé.

## Essai historique : état, provenance et reconstruction

Les quatre fits TP ont terminé dans le job `3232534` (tâches 10 et 11). Les dix tâches TB ont échoué avant entraînement parce que leur chemin ne contenait pas `Kronos`, exigé par le chargeur original. Un alias du même dossier généré corrige le chemin ; les caches déjà préparés sont réutilisés explicitement. Aucune modification des données, des targets ou de la pipeline ne découle de cette correction.

Relance TB : job `3232691` (20 fits), rapport : `3232692` ; les deux ont terminé avec succès. Pour cet ancien Test uniquement, les chiffres sont dans les fichiers suivants :

- `pilot_results/original_test/slide_data.json` : effectifs reçus, cellules manquantes, dates, baseline et résultats.
- `pilot_results/original_test/experiment_test.csv` et `.md` : tous les résultats reçus et différences par rapport à TB ref et au TP original, avec les comptes d’entraînement.
- `pilot_results/original_test/provenance.json` : manifeste, configuration, empreintes des résultats.
- `figures/target_trial_sharpe_matrix.svg` : matrice historique complète.
- `target_trial_slides.typ` : trois slides historiques, désormais utilisées dans `earlier_target_trial.pdf` et retirées des deux présentations courantes.

Les figures initiales de labels restent dans `analysis/out/brief_fit20_*`. Leur nom historique ne signifie plus que le filtre `fit20` a été utilisé : l'univers est celui de SecondaryModel, avec TON absent du parquet diagnostique.

Depuis la racine du dépôt :

    rtk proxy code/SecondaryModel/.venv/bin/python report/triple_barrier/analysis/sync_target_trial.py

Cette commande récupère les résultats disponibles, vérifie leur parité, régénère les tableaux et la figure, puis compile les deux PDF. Elle ne réentraîne aucun modèle et ne remplace jamais un résultat manquant par celui d'une ancienne expérience.

## Archive — relance et vérifications du moteur spread

Run `gpu8-targets-20261027-153632` : préparation 3233005, matrice 3233006, rapport 3233007. Checkout isolé `code/SecondaryModel-gpu8`, révision GPU8 5b61d08. Cutoffs : début 2024-07-01, fin train 2025-08-31, fin validation 2025-12-31, fin données 2026-08-01. La référence Test à reproduire contient les entrées 2026-01-08–2026-07-18.

24 fits : AutoGluon/Kumo × TP, référence TB appariée, k = 0,5/1/1,5/2 × UP/DOWN, granularité 1d, exécution fixe à 7 bougies. Les arguments CLI sélectionnent ces backends et cette granularité ; le YAML de base conserve la liste de Pablo. Les versions principales des bibliothèques sont figées sur GPU8, avec LightGBM et CatBoost disponibles. La préparation doit vérifier les 280 CSV, l'environnement, les apprenants et le baseline M1 dans chaque bras avant les entraînements. Le patch Python et le matériel diffèrent ; des prédictions M2 strictement identiques ne sont pas garanties. Pas de jobs HPO, edge ou régime séparés.

Le téléchargement de cette nouvelle expérience est indépendant du précédent :

    rtk proxy python3 report/triple_barrier/analysis/sync_gpu8_trial.py --run-id gpu8-targets-20261027-153632

Un watcher local est lancé pour 12 heures maximum ; il nécessite que le PC et le VPN restent disponibles. Les poids et caches restent sur Izar. Les PDF gardent les résultats précédents clairement datés jusqu'à la vérification des nouveaux résultats. Le Test déjà consulté reste exploratoire.

### Vérification du 28 octobre

La préparation 3233005 avait échoué : aucun des 24 fits de cette relance n'a tourné. Notre vérificateur conservait 32 lignes Test UP sans rendement réalisé, alors que le backtest de Pablo les retire. Correction limitée au vérificateur, avec tests UP/DOWN contre le vrai moteur : 77 tests passent. Sur le cache UP réel, les 1 045 trades restants reproduisent le baseline spread : rendement −54,247780 %, drawdown −57,991160 %, Sharpe −2,574429 ; entrées 2026-01-08–2026-07-18, 192 bougies et 27 rendements hebdomadaires.

Relance corrigée `gpu8-targets-20261028-104504` : préparation 3233490, matrice 3233491, rapport 3233492. Les dépendances bloquées de l'ancien run sont annulées. Le watcher pointe désormais sur ce nouveau run. Pour récupérer ses fichiers :

    rtk proxy python3 report/triple_barrier/analysis/sync_gpu8_trial.py --run-id gpu8-targets-20261028-104504

Autre différence vérifiée : le rapport cash sauvegardé de Pablo conserve les positions ouvertes au coût d'entrée (UP : rendement −43,60 %, drawdown −45,35 %, Sharpe −2,79). Le code cash actuel les valorise aux cours courants ; avec les mêmes trades, il donne −43,66 %, −48,75 % et −2,14. Les petites différences de rendement final incluent les frais sur les entrées du dernier jour, qui restent ouvertes au point final. Ne pas présenter ce rendement comme celui d'un portefeuille entièrement liquidé. Le code de production reste inchangé ; ces conventions doivent être distinguées dans les comparaisons.

Les contrôles indépendants locaux en 1d passent aussi pour les six targets dans les deux directions : mêmes trades Test réalisés et mêmes métriques M1 entre targets. DOWN : +30,440865 % de rendement, −17,036193 % de drawdown, Sharpe +1,742319, 2 580 trades. TP retire 32 lignes UP et 90 DOWN sans rendement réalisé. La préparation cluster doit encore vérifier les caches multigranularités. Dates effectivement sélectionnées par le loader original : train 2024-06-30–2025-08-31 (un jour avant le début configuré, par convention de fenêtre de contexte), Val-Cal 2025-09-08–2025-10-18, Val-Opt 2025-10-26–2025-12-31 ; Test réalisé 2026-01-08–2026-07-18. Source : `pilot_results/gpu8_target_trial/gpu8-targets-20261028-104504/local_daily_baselines.json`.
