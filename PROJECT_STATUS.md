# État du projet

Dernière mise à jour : 2026-11-16. Règle : une fonctionnalité n'est marquée « faite » qu'avec du code et un test ou une démonstration.

## Plan

| Étape | Contenu | État |
|---|---|---|
| 1 | Socle multiplateforme + chapitre pilote | Fait (PR #1) |
| 2 | Base pédagogique complète, ≥ 500 questions originales relues | **En cours** : 9 chapitres sur 17, 264 questions |
| 3 | Tuteur : version sans IA, puis modèle local optionnel | À faire |
| 4 | Simulateur SOC, sauvegarde chiffrée, import/export, installateurs, documentation finale | À faire |

## Étape 2 : avancement du contenu

| Chapitre | Leçons | Questions | Flashcards | État |
|---|---|---|---|---|
| M1 ch. 1 · Gestion, analyse et traitement des risques | 3 | 24 | 20 | Fait, à relire |
| M1 ch. 2 · Gouvernance et management de la sécurité | 3 | 30 | 20 | Fait, à relire |
| M1 ch. 3 · Politiques, normes, procédures et famille ISO 27000 | 3 | 30 | 20 | Fait, à relire |
| M1 ch. 4 · IAM, authentification et contrôle d'accès (format cahier dès l'écriture) | 3 | 30 | 20 | Fait, à relire |
| M2 ch. 1 · Opérations de sécurité, journalisation, SIEM et SOC (format cahier) | 3 | 30 | 20 | Fait, à relire |
| M2 ch. 2 · Cryptographie, signatures, certificats et PKI (format cahier, carte mentale) | 3 | 30 | 20 | Fait, à relire |
| M2 ch. 3 · Gestion des vulnérabilités et des correctifs (format cahier, carte mentale) | 3 | 30 | 20 | Fait, à relire |
| M3 ch. 1 · Modèles OSI, TCP/IP et protocoles sécurisés (format cahier, carte mentale) | 3 | 30 | 20 | Fait, à relire |
| M3 ch. 2 · Pare-feu, IDS/IPS, VPN, segmentation et sans-fil (format cahier, carte mentale) | 3 | 30 | 20 | Fait, à relire |
| 9 autres chapitres | – | – | – | À faire, dans l'ordre de la formation |

Glossaire : 176 termes.

## Étape 1 : détail

| Élément | État | Preuve |
|---|---|---|
| Chargement et validation du contenu JSON | Fait | `test/content_test.dart` |
| Stockage SQLite local, persistance après réouverture | Fait | `test/sqlite_store_test.dart` |
| Correction des QCM (choix unique et multiple) | Fait | `test/quiz_engine_test.dart` |
| Examen blanc réparti selon le poids des domaines, durée au prorata | Fait | `test/quiz_engine_test.dart` |
| Répétition espacée SM-2 | Fait | `test/spaced_repetition_test.dart` |
| Progression, maîtrise (80 %), lacunes, recommandation | Fait | `test/stats_test.dart` |
| Écrans : accueil, cours, leçon, fiche, QCM, résultat, examen blanc, flashcards, glossaire | Fait | `test/widget_test.dart` + captures de l'aperçu |
| Navigation téléphone (barre du bas) et grand écran (rail latéral) | Fait | `test/widget_test.dart` |
| Chapitre pilote : 3 leçons, 24 questions, 20 flashcards, fiche de révision | Fait, **à relire** | `assets/content/m1c1_risques.json` |
| Glossaire : 32 termes | Fait, **à relire** | `assets/content/glossary.json` |
| Compilation Android, Linux, Windows, macOS | Configurée, **à confirmer par la première exécution GitHub Actions** | `.github/workflows/build.yml` |

## Design « cahier manuscrit » : phase 1 (tableau de bord et chapitre modèle)

| Élément | État | Preuve |
|---|---|---|
| Polices manuscrites embarquées hors ligne (Caveat, Patrick Hand, Kalam) + Nunito et JetBrains Mono, licences OFL incluses | Fait | `assets/fonts/`, `pubspec.yaml` |
| Code couleur fixe (bleu définitions, violet important, vert bonnes pratiques, orange à retenir, rouge risques, jaune notes, turquoise exemples, rose pièges) | Fait | `lib/ui/notebook/palette.dart` |
| Papier crème ligné, encadrés à contour dessiné à la main, post-it pour notes et mémos | Fait | `lib/ui/notebook/` + captures |
| Nouveaux blocs de leçon : note du formateur, mémorisation, important, bonne pratique, risque, schéma, illustration, petit test | Fait | `test/content_test.dart`, `test/widget_test.dart` |
| Schémas interactifs : chaîne, cycle, matrice 5×5, barres, grille 2×2 ; description accessible obligatoire | Fait | `lib/ui/notebook/diagrams.dart`, validation dans `content_loader.dart` |
| Chapitre modèle « Gestion des risques » enrichi : 3 illustrations, 5 schémas, notes, mémos, petits tests | Fait, **à valider** | `assets/content/m1c1_risques.json`, `assets/illustrations/` |
| Tableau de bord : illustration d'accueil, anneau de progression, 5 modules colorés, courbe des scores, radar des 11 domaines, camembert, maîtrise des chapitres, 8 badges, objectif du jour (20 réponses), série de jours, accès rapide ; 2 colonnes sur grand écran | Fait, **à valider** | `lib/ui/dashboard_page.dart`, `test/stats_test.dart` |
| Flashcards façon fiche bristol : retournement 3D, couleur du module, difficulté, animation « carte maîtrisée » | Fait | `lib/ui/flashcards_page.dart`, `test/widget_test.dart` |
| Animations légères désactivables (Réglages) et respect du réglage système « réduire les animations » | Fait | `test/widget_test.dart`, migration SQLite v2 testée dans `test/sqlite_store_test.dart` |
| Pages Cours, Chapitre, QCM et examens, Flashcards, Glossaire, Fiche de révision et Résultats au style cahier (bandeaux en dégradé, cartes dessinées, gommettes, boutons colorés) | Fait | `lib/ui/notebook/page_kit.dart`, `test/widget_test.dart` (« cours, chapitre et fiche suivent le style cahier ») |
| Chapitres « Gouvernance » et « Politiques, ISO 27000 » au format cahier : 6 illustrations, 7 schémas (dont NIST CSF 2.0, PDCA, 93 mesures de l'annexe A), notes, mémos, petits tests | Fait, **à relire** | `assets/content/m1c2_gouvernance.json`, `assets/content/m1c3_politiques.json`, `test/content_test.dart` (chaque leçon : illustration, schéma, petit test, note ou mémo) |
| Cartes mentales interactives : une par chapitre (rédigée dans le contenu), une par module et une pour toute la formation (11 domaines et leurs poids) ; branches repliables, zoom, vue liste sur téléphone. Carte du chapitre 1 développée à partir de l'exemple fourni par l'apprenant | Fait, **à valider** | `lib/ui/mind_map_page.dart`, clé `mindMap` des chapitres, `test/content_test.dart`, `test/widget_test.dart` |
| Recherche globale (loupe sur chaque page) : glossaire, titres des chapitres et leçons, sections, flashcards, nœuds des cartes mentales ; en français ou en anglais, sans tenir compte des accents ni des majuscules ; filtres par type | Fait | `lib/logic/search.dart`, `lib/ui/search_page.dart`, `test/search_test.dart`, `test/widget_test.dart` (« un terme anglais retrouve le glossaire ») |
| Termes clés en français et en anglais : titres des chapitres et modules, définitions, flashcards, fiches, cartes mentales ; dans le texte des leçons, l'anglais est ajouté entre parenthèses à la première occurrence d'un terme du glossaire | Fait, **à relire** | `lib/logic/terms.dart`, `lib/ui/bilingual.dart`, clé `titleEn` du catalogue, `test/search_test.dart` |
| Menu « Révisions » (remplace l'onglet Flashcards) : flashcards, fiches et cartes mentales, par chapitre, par module ou pour toute la formation | Fait | `lib/ui/revisions_page.dart`, `test/widget_test.dart` (« révisions : trois supports, filtre par module ») |
| Téléchargement PDF des fiches, des flashcards (recto/verso) et des cartes mentales (image + plan détaillé), par chapitre ou par module. Windows : dossier Téléchargements ; Android : feuille de partage | Fait ; enregistrement réel à essayer sur Android et Windows | `lib/export/`, `test/pdf_test.dart` |
| Application du design aux chapitres suivants, schémas par chapitre (OSI, PDCA, SOC, IR, PKI, PCA/PRA, RTO/RPO, Zero Trust…) | À faire, après validation | |
| Essai sur un vrai téléphone Android et sur ordinateur (hors aperçu web) | À faire | |

## Écarts connus et décisions

- **5 modules / 11 domaines** : l'application affiche les 5 modules du cahier des charges ; chaque chapitre et chaque question est rattaché à l'un des 11 domaines officiels du blueprint MILE2 (poids vérifiés le 2026-11-16). La sécurité physique n'a pas de domaine propre dans le blueprint.
- **Seuil de réussite** : 62/100 selon le blueprint MILE2 consulté ; certaines fiches de formation tierces indiquent 70 %. À revérifier avant l'inscription.
- **Fiches de révision** : consultables et copiables ; l'export en fichier arrivera avec l'import/export (étape 4).
- **Examen blanc** : limité à la banque disponible (84 questions) jusqu'à la fin de l'étape 2.
- **Ressources vidéo** : pas encore de bibliothèque ; aucune vidéo ne sera listée sans vérification.
- **Emoji des encadrés** : affichés par la police emoji du système (Android, Windows, macOS en ont une). Sur Linux, il faut le paquet Noto Color Emoji ; sinon des carrés vides peuvent apparaître.
- **Signature** : APK signé avec la clé de débogage ; applications ordinateur non signées.

## Comment lancer les tests

```bash
flutter test
```
