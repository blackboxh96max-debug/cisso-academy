# CISSO Academy

Application de préparation à la certification **CISSO** (Certified Information Systems Security Officer) de MILE2.
Elle fonctionne **entièrement hors ligne** sur Android et Windows : cours, QCM, examens blancs, flashcards, glossaire et statistiques restent sur l'appareil, sans compte ni abonnement.

> Projet indépendant, sans lien avec MILE2. Les questions sont originales : elles ne reproduisent pas les questions de l'examen.

## Fonctionnalités (étape 1)

| Fonction | État |
|---|---|
| Tableau de bord : progression globale et par module, score moyen, questions traitées, chapitres maîtrisés / à revoir, prochaine révision recommandée | ✅ |
| Cours structurés : objectifs, définitions, tableaux, étapes, cas SOC, points de vue (RSSI, SOC, auditeur, risk manager), pièges, résumé | ✅ |
| Fiche de révision par chapitre (consultable et copiable) | ✅ |
| QCM par chapitre : niveaux, questions aléatoires, choix unique ou multiple, correction détaillée, mode chronométré | ✅ |
| Reprise des questions ratées | ✅ |
| Examen blanc chronométré, réparti selon le poids officiel des domaines, avec analyse des erreurs | ✅ |
| Flashcards à répétition espacée (SM-2) | ✅ |
| Glossaire bilingue anglais / français avec recherche hors ligne | ✅ |
| Recherche globale (termes, chapitres, leçons, flashcards, cartes mentales), en français ou en anglais | ✅ |
| Termes clés affichés en français et en anglais dans les cours, fiches, flashcards et cartes | ✅ |
| Menu Révisions : flashcards, fiches et cartes mentales par chapitre ou par module, export PDF | ✅ |
| Suivi des erreurs par notion et par domaine officiel | ✅ |
| Contenu : modules 1 et 2 complets et 1er chapitre du module 3 (234 questions) | ✅ (étape 2 en cours) |

Le détail de ce qui est fait, testé et prévu se trouve dans [PROJECT_STATUS.md](PROJECT_STATUS.md).

## Télécharger l'application

Chaque mise à jour de `main` est compilée par GitHub Actions (onglet **Actions**, artefacts en bas de l'exécution) :

- `cisso-academy-android` : APK à installer sur téléphone ou tablette (autoriser les « sources inconnues ») ;
- `cisso-academy-windows` : archive à décompresser.

Une étiquette `v*` (par exemple `v0.1.0`) publie automatiquement ces fichiers dans **Releases**.

## Développer

```bash
flutter pub get
flutter test          # tests automatisés
flutter run -d windows  # ou un appareil Android
```

Version de Flutter utilisée : 3.50.0 (stable). Voir [docs/COMPILATION.md](docs/COMPILATION.md).

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Format du contenu pédagogique](docs/CONTENU.md)
- [Compilation et déploiement](docs/COMPILATION.md)
- [Guide utilisateur](docs/GUIDE_UTILISATEUR.md)
