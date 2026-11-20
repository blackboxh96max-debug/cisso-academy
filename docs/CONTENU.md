# Format du contenu pédagogique

Tout le contenu se trouve dans `assets/content/`. Il est validé au démarrage de l'application et par `test/content_test.dart` : un identifiant en double, un domaine inconnu, une bonne réponse invalide ou une explication manquante bloque le chargement.

## Règles éditoriales (cahier des charges §8)

Chaque élément porte une nature (`kind`) affichée dans l'application :

| `kind` | Affichage | Usage |
|---|---|---|
| `official` | Officiel MILE2 | Exigence de la certification, vérifiée sur une source MILE2 |
| `general` | Connaissance générale | Normes et publications de référence (ISO, NIST, ANSSI, OWASP, CISA) |
| `practice` | Bonne pratique | Pratique professionnelle reconnue |
| `example` | Exemple pédagogique | Cas fictif créé pour l'application |

- Ne jamais inventer de référence, de lien ou de règle d'examen. Un lien n'est ajouté que s'il a été vérifié.
- Les questions sont originales ; elles ne prétendent pas reproduire l'examen.
- Chaque question a 4 choix, une explication de la bonne réponse et une explication pour chaque mauvais choix.

## `catalog.json`

- `exam` : paramètres officiels vérifiés (nombre de questions, durée, seuil, source, date de vérification).
- `domains` : les 11 domaines officiels et leur poids en % (total 100).
- `modules` : les 5 modules affichés, chacun avec ses chapitres. Un chapitre avec `file` est disponible ; sans `file`, il apparaît « à venir ».

## Fichier de chapitre (ex. `m1c1_risques.json`)

```json
{
  "lessons": [{ "id": "...", "title": "...", "minutes": 25, "objectives": ["..."],
                "references": [{ "title": "...", "url": "https://...", "kind": "general" }],
                "blocks": [ ... ] }],
  "questions": [{ "id": "...", "domain": "risk-management", "level": "beginner|intermediate|advanced",
                  "concept": "Notion évaluée", "prompt": "...", "choices": ["A", "B", "C", "D"],
                  "correct": [1], "explanation": "...", "whyNot": { "0": "...", "2": "...", "3": "..." },
                  "kind": "general" }],
  "flashcards": [{ "id": "...", "front": "...", "back": "...", "concept": "..." }],
  "revisionSheet": ["# Titre", "Ligne 1", "Ligne 2"]
}
```

Types de blocs de leçon : `heading`, `text`, `bullets`, `definition`, `socCase`, `viewpoints` (lignes « Rôle : avis »), `table` (première ligne = en-tête), `steps`, `pitfalls`, `summary`.

Plusieurs bonnes réponses dans `correct` font une question à réponses multiples. L'ordre des choix est mélangé à l'affichage : ne pas écrire « réponse A » dans les explications.

## `glossary.json`

```json
[{ "id": "ale", "en": "Annualized Loss Expectancy", "fr": "Espérance de perte annuelle",
   "acronym": "ALE", "definition": "...", "example": "...", "kind": "general" }]
```

## `regulations.json` (Textes et normes)

Fiches courtes, bilingues, sur les normes et règlements (déclarées par `"regulations"` dans `catalog.json`). Ce ne sont pas des leçons : pas de QCM ni de flashcards.

```json
{ "verifiedOn": "2026-11-20", "intro": {"fr": "...", "en": "..."}, "notice": {"fr": "...", "en": "..."},
  "groups": [{ "id": "...", "emoji": "📐", "title": {"fr": "...", "en": "..."},
    "items": [{ "id": "nis2", "name": "NIS 2", "title": {...}, "nature": {...}, "reference": {...},
                "status": {...}, "definition": {...}, "essentials": [{...}], "remember": {...},
                "lessons": ["m5c5-l3"], "links": [{ "label": {...}, "url": "https://..." }],
                "kind": "general" }] }] }
```

- Chaque texte existe en français et en anglais ; 3 à 6 points essentiels.
- `lessons` renvoie vers les leçons qui approfondissent le sujet (identifiants vérifiés au chargement).
- Les liens ne viennent que de sites officiels (liste `regulationHosts` dans `content_loader.dart`) et sont vérifiés avant d'être ajoutés.
