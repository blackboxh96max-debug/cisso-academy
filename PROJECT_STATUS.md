# État du projet

Dernière mise à jour : 2026-11-16. Règle : une fonctionnalité n'est marquée « faite » qu'avec du code et un test ou une démonstration.

## Plan

| Étape | Contenu | État |
|---|---|---|
| 1 | Socle multiplateforme + chapitre pilote | **En revue** (cette pull request) |
| 2 | Base pédagogique complète, ≥ 500 questions originales relues | À faire |
| 3 | Tuteur : version sans IA, puis modèle local optionnel | À faire |
| 4 | Simulateur SOC, sauvegarde chiffrée, import/export, installateurs, documentation finale | À faire |

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

## Écarts connus et décisions

- **5 modules / 11 domaines** : l'application affiche les 5 modules du cahier des charges ; chaque chapitre et chaque question est rattaché à l'un des 11 domaines officiels du blueprint MILE2 (poids vérifiés le 2026-11-16). La sécurité physique n'a pas de domaine propre dans le blueprint.
- **Seuil de réussite** : 62/100 selon le blueprint MILE2 consulté ; certaines fiches de formation tierces indiquent 70 %. À revérifier avant l'inscription.
- **Fiches de révision** : consultables et copiables ; l'export en fichier arrivera avec l'import/export (étape 4).
- **Examen blanc** : limité à la banque disponible (24 questions) jusqu'à l'étape 2.
- **Ressources vidéo** : pas encore de bibliothèque ; aucune vidéo ne sera listée sans vérification.
- **Signature** : APK signé avec la clé de débogage ; applications ordinateur non signées.

## Comment lancer les tests

```bash
flutter test
```
