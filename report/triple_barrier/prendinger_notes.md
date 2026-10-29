# Discussion avec le professeur Prendinger — notes et résultats du test original

Préparation : 22 octobre 2026 ; résultats mis à jour le 29 octobre. Présentation en anglais, notes de préparation en français.

## La proposition

Présenter le diagnostic des labels, le baseline GPU8 reproduit, puis les **48 résultats M2 terminés et vérifiés** : AutoGluon, Kumo, TabPFN et Random Forest. La slide 12 définit TP ; les slides 13–15 montrent tous les Sharpes et les deux deltas. Le baseline UP reste négatif : −2,5744. L'ancienne matrice positive en UP est conservée dans `earlier_target_trial.pdf`, sur son Test 2025-10-09–2026-01-18.

**TP signifie true positive, pas take profit.** Parmi les propositions Kronos, label 1 signifie que le rendement signé au jour 7 dépasse les frais de 0,2 % ; sinon label 0. Le signe est inversé pour DOWN. La colonne TP correspond à un M2 entraîné sur ce label initial. TB ref garde ce label avec le filtre d'éligibilité TB ; TB-k change la cible selon l'issue des barrières. L'exécution du backtest reste à J+7 pour toutes les colonnes.

TabPFN et RF utilisent les paramètres HPO_NoCal sauvegardés chez Pablo, figés par direction et conservés entre targets. RF : 100 arbres / profondeur 3 UP, 900 / profondeur 12 DOWN. TabPFN : 4 estimateurs UP et 32 DOWN. Jobs : préparation 3234260, entraînement 3234261, rapport 3234262. Il s'agit de 24 fits supplémentaires, sans relancer les 24 AG/Kumo déjà terminés.

Résultat principal sur le Test **2026-01-08–2026-07-18** : AutoGluon DOWN à k=0,5 atteint 1,8216 de Sharpe, soit +1,4831 contre son nouveau TP, mais seulement +0,3695 contre TB ref à éligibilité identique. Le drawdown est plus profond : −26,55 %, contre −13,95 % pour TB ref. Pour AutoGluon et Kumo, aucun TB-k ne dépasse le TP en UP ; les quatre TB-k de Kumo sont également sous son TP en DOWN. Kumo DOWN TB ref obtient 2,0008 ; ce contrôle conserve les labels TP.

Les 24 nouveaux fits ont terminé avec succès, ainsi que leur rapport. TabPFN DOWN à k=0,5 passe de 0,8822 (TP) à **1,5687** : +0,6865 contre TP, **+0,5804 contre TB ref**. Il reste sous le Sharpe M1 DOWN de 1,7423. Random Forest UP à k=1,5 passe de −1,8000 à **−1,3877** : +0,4123 contre TP, **+0,1296 contre TB ref**, mais le rendement reste négatif (−34,6094 %). RF DOWN à k=1,5 gagne seulement +0,0201 contre TP et perd −0,0244 contre TB ref. Tous les Sharpes UP de la matrice restent négatifs.

Les 77 observations TON retirées de l'entraînement (13 UP, 64 DOWN) expliquent pourquoi le delta contre TP ne mesure pas uniquement le changement de label. Les trades Test réalisés et les features sont identiques entre les 48 fits. Trois cellules utilisent le seuil de repli 0,5 : AutoGluon UP TB ref et k=1, ainsi que TabPFN UP k=0,5. La contrainte d'utilité n'a pas été satisfaite dans ces cas. Les nouvelles performances TP ne reproduisent pas exactement les anciens modèles de Pablo ; comparer les targets aux nouveaux TP de ce même run.

Les 288 métriques M1/M2 ont été rejouées depuis les CSV, avec un écart inférieur à 0,0001. Les 24 nouveaux fits ont bien chargé les paramètres GPU8 : contrôle des fichiers et des logs de production. Une exécution par cellule, 27 observations hebdomadaires, Test déjà inspecté : résultat exploratoire, pas de sélection d'un k optimal ni de preuve de significativité. L'exécution reste fixée au jour 7. Les notes méthodologiques ci-dessous conservent le contexte des diagnostics initiaux.

Conserver pour ce premier test les bougies OHLC journalières actuelles, les sorties de Kronos déjà calculées, les mêmes features et un horizon maximum de 7 bougies. Changer le label n'impose ni une nouvelle représentation des bougies ni un réentraînement de M1.

## Périmètre exact et reproductibilité

Cette présentation utilise les lignes du fichier real/1d.parquet correspondant aux 20 actifs déjà couverts par les prévisions Kronos de SecondaryModel (et non la colonne fit20, qui est la cohorte de calibration du modèle de régime de Synthetic-Generation, sans rapport avec la couverture Kronos — seuls 13 des 20 actifs se recoupent), avec period = train, embargo = False, pred_class dans UP/DOWN et kronos_valid = True.

- 20 actifs.
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

## Slide 2 — Faut-il réentraîner M2 ?

Trois opérations différentes :

| Opération | Nouvel entraînement ? |
|---|---|
| Mesurer σ, poser des barrières, recalculer les labels | Non |
| Évaluer d'autres sorties avec les mêmes signaux/scores existants | Non, mais cela teste les sorties |
| Apprendre à prédire le nouveau meta-label | Oui pour M2 ; pas pour M1 |

Les targets historiques se calculent en regardant les futurs réalisés. Les features de M2 restent celles disponibles à l'entrée.

Avec le recipe actuel, les modèles long et short sont séparés. Deux versions de target impliquent donc quatre modèles par seed pour un k fixé : baseline UP/DOWN et TB UP/DOWN. Si l'on choisit un modèle partagé avec la direction en feature, le compte change. Il ne faut pas confondre cette organisation de M2 avec le nombre de k.

Pour une recherche complète de k, chaque candidat change le target : il faut donc aussi ajuster M2 pour ce target sur l'entraînement. Les prédictions de M1 sont réutilisables si les événements et features restent inchangés.

## Slide 3 — Bougies habituelles et application aux deux directions

Exemple réel BTC, entrée au close du 3 juillet 2024, signal Kronos UP. L'exemple a été sélectionné dans l'entraînement parce qu'il illustre clairement un stop avant l'expiration, sans ambiguïté de double touche.

Largeur k = 1 : environ 6,44 %. Le prix est normalisé à 100 à l'entrée.

- Long : barrière basse = stop ; sortie jour 2 ; net environ −6,64 % ; label 0.
- Short au même point, présenté uniquement comme illustration contrefactuelle : barrière basse = profit ; net environ +6,24 % ; label 1.

Le panneau short n'est pas une deuxième prédiction réelle de Kronos.

Une même date et un même actif donnent la même volatilité pour les deux côtés. On applique les seuils au rendement de la position s(P/P₀−1), où s vaut +1 ou −1. Avec des distances symétriques, les prix des barrières sont les mêmes et leurs rôles s'inversent. Avec des distances profit/stop asymétriques, les niveaux et la sortie peuvent changer en inversant le côté.

Les bougies futures créent le label. Elles ne deviennent pas des inputs de M2.

## Slide 4 — Volatilité par actif et dans le temps

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

## Slide 5 — Différences UP/DOWN

Mesures à k = 1 sur les propositions réelles, pondérées par événement à l'intérieur de chaque direction :

| Direction | N | Positifs actuels | Positifs TB | Labels modifiés |
|---|---:|---:|---:|---:|
| UP | 1 921 | 50,7 % | 49,6 % | 5,9 % |
| DOWN | 5 672 | 49,2 % | 48,9 % | 4,4 % |

Les sorties sont proches ici : environ 25–27 % de profits, 28–32 % de stops et 44–45 % d'expirations.

Les proportions de labels positifs ne sont pas l'accuracy de M2 : M2 n'intervient pas dans cette mesure. Les groupes UP et DOWN ne contiennent pas les mêmes dates ni les mêmes conditions de marché ; cette comparaison ne prouve pas qu'un côté exige une autre estimation de σ ou un autre k.

Le fichier brief_fit20_asset_direction.csv fournit aussi la ventilation par actif, direction et k. Examiner les effectifs avant d'interpréter une petite sous-population. On ne compte qu'une double touche à k = 1 dans ce périmètre.

## Slide 6 — Ce que montre la grille de k

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

## Slide 7 — Comment choisir k ?

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

## Quatre slides d'ouverture — Dates, baseline vérifié, valorisation et référence GPU8

Après la couverture, les pages 2 à 5 montrent successivement les périodes exactes, les résultats M1 reproduits, les trois conventions de calcul du portefeuille et les résultats M2 sauvegardés de Pablo. La couverture et la slide de baseline affichent le Sharpe UP −2,5744 ; la colonne UP du tableau de Pablo est mise en évidence. Les deux vagues AG/Kumo et TabPFN/RF sont terminées : 48 / 48 fits vérifiés et affichés sur les slides finales. Les 24 fits de l'ancien essai ont leur propre PDF historique.

La configuration locale reprend désormais celle observée sur GPU8, seuls les chemins de fichiers étant adaptés : début 2024-07-01, fin train 2025-08-31, fin validation 2025-12-31, fin des données 2026-08-01. Les 280 CSV TP sont identiques octet par octet à GPU8. Cela ne transforme pas les résultats du précédent run en résultats de ce nouveau protocole.

Les dates d'entrée réellement utilisées sont affichées séparément : diagnostics de labels 2024-07-01–2025-08-24 ; matrice AG/Kumo terminée, Test 2025-10-09–2026-01-18 ; résultats enregistrés de Pablo, Test 2026-01-08–2026-07-18. Le benchmark LightGBM distinct utilise les entrées train 2024-07-01–2025-08-24, validation 2025-09-01–2025-12-24 et Test 2026-01-01–2026-09-23. Ce sont des dates d'entrée, pas nécessairement les dates finales de liquidation ou de P&L.

Les huit résultats 1d TP de Pablo (AutoGluon, CTTS, TabPFN, TabICL, UP/DOWN) ont été téléchargés puis rejoués avec le moteur spread-equity local : les 48 métriques M1/M2 de rendement, drawdown et Sharpe concordent à moins de 0,0001. Les CSV arrondissent les rendements à six décimales. Ce contrôle réutilise les décisions enregistrées de Pablo ; il ne réentraîne aucun classifieur. Le Test comporte 192 barres et 27 rendements hebdomadaires.

Le « −45 % » correspond notamment au drawdown M1 UP du rapport cash-account : rendement −43,60 %, drawdown −45,35 %. Le rapport spread-equity, sur les mêmes dates, donne rendement −54,2478 % et Sharpe −2,5744. Nommer le moteur et la métrique à chaque comparaison.

La reproduction de l'entraînement reste à vérifier. L'ancien essai Izar utilisait `9a272f5` et ignorait LightGBM faute de dépendance. La nouvelle copie isolée utilise le commit GPU8 `5b61d08` et les versions principales observées chez Pablo, avec LightGBM disponible. La préparation corrigée, les 24 fits et le rapport sont terminés. Les nouveaux TP diffèrent numériquement des anciens M2 de Pablo ; les deltas utilisent les contrôles du nouveau run. Les sorties de référence sont dans `pilot_results/gpu8_reference_5b61d08/`, et leur replay spread est reproductible avec `analysis/replay_gpu8_reference.py`.

## Slides finales — Le test réellement lancé

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

## Lecture prudente du Sharpe

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

## Relance aux dates de Pablo — soumise le 27 octobre 2026 UTC

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
