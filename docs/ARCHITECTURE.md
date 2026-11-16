# Architecture

## Choix techniques

| Besoin | Choix | Raison |
|---|---|---|
| Android + Windows + macOS + Linux avec une seule base de code | **Flutter** (Dart) | Un seul code d'interface pour les quatre plateformes. |
| Données locales | **SQLite** via le paquet `sqlite3` | SQLite est embarqué dans l'application : aucune dépendance système, fonctionne hors ligne. |
| Contenu pédagogique | **Fichiers JSON** dans `assets/content/` | Lisibles, relisibles en revue de code, validés automatiquement au chargement et par les tests. |
| Tuteur IA (étape 3) | Version sans IA d'abord, puis moteur local optionnel (llama.cpp) | Le cahier des charges exige un mode sans modèle génératif. |

## Organisation du code

```
lib/
  main.dart                 Démarrage : charge le contenu, ouvre la base, lance l'interface
  app_state.dart            État partagé (contenu, stockage, statistiques)
  models/content.dart       Modèle du contenu (modules, chapitres, leçons, questions…)
  content/content_loader.dart  Chargement + validation du contenu JSON
  data/
    progress_store.dart     Interface de stockage + implémentation mémoire
    sqlite_store.dart       Implémentation SQLite (schéma versionné)
    store_factory*.dart     Choix de l'implémentation selon la plateforme
  logic/
    quiz_engine.dart        Correction, tirage des questions, composition des examens blancs
    spaced_repetition.dart  Algorithme SM-2 des flashcards
    stats.dart              Progression, maîtrise, lacunes, recommandation
  ui/                       Écrans (tableau de bord, cours, QCM, flashcards, glossaire)
assets/content/             Contenu pédagogique (JSON)
test/                       Tests automatisés
```

La logique (`logic/`, `data/`, `content/`) ne dépend pas de l'interface : elle est testée directement.

## Données stockées sur l'appareil

Base `cisso_academy.db` dans le dossier de données privé de l'application (`getApplicationSupportDirectory`).

| Table | Contenu |
|---|---|
| `answers` | Chaque réponse : question, chapitre, domaine, notion, choix, juste/faux, mode, date |
| `sessions` | Chaque série terminée : mode, score, durée, date |
| `cards` | État de répétition espacée de chaque flashcard |
| `lessons_read` | Leçons lues |

Aucune donnée personnelle n'est demandée ni envoyée. L'APK Android de production ne déclare pas la permission Internet.
Le schéma est versionné (`PRAGMA user_version`) pour permettre des migrations.

## Règles de calcul

- **Correction** : une question à réponses multiples n'est juste que si toutes les bonnes réponses, et seulement elles, sont cochées.
- **Dernière réponse** : pour la maîtrise et la reprise des erreurs, seule la dernière réponse à chaque question compte.
- **Chapitre maîtrisé** : au moins 80 % des questions vues et au moins 80 % de réussite (règle 8/10 de la formation).
- **Chapitre à revoir** : au moins 5 questions vues et moins de 80 % de réussite.
- **Progression d'un chapitre** : 40 % leçons lues + 30 % questions vues + 30 % réussite pondérée par la couverture.
- **Lacune récurrente** : au moins deux erreurs sur une notion, dont une encore ouverte.
- **Prochaine révision** (par priorité) : flashcards échues, lacune récurrente, leçon non lue, chapitre non maîtrisé, erreurs restantes, examen blanc.
- **Examen blanc** : questions réparties selon le poids officiel des domaines (redistribution si un domaine manque de questions) ; durée au prorata de l'examen officiel (120 min pour 100 questions, soit 72 s par question).
- **Flashcards (SM-2)** : intervalles 1 jour, 6 jours, puis intervalle × facilité ; facilité minimale 1,3 ; carte maîtrisée à 21 jours d'intervalle.

## Aperçu web

Une compilation web existe uniquement pour l'aperçu et les captures d'écran (progression en mémoire, non conservée). Ce n'est pas une cible du cahier des charges.
