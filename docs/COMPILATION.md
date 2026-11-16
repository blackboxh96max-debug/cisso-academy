# Compilation et déploiement

## Automatique (recommandé)

Le workflow `.github/workflows/build.yml` s'exécute à chaque pull request et à chaque mise à jour de `main` :

1. **Analyse et tests** (`flutter analyze`, `flutter test`) ;
2. si tout est vert, compilation **Android (APK)**, **Linux**, **Windows** et **macOS** en parallèle ;
3. les fichiers sont disponibles en artefacts de l'exécution (onglet Actions).

Pour publier une version : créer une étiquette `vX.Y.Z` sur `main` et la pousser. Le job « Publication » attache les quatre fichiers à une Release GitHub.

## Manuelle

Prérequis : Flutter 3.50.0 (stable).

| Cible | Prérequis supplémentaires | Commande | Résultat |
|---|---|---|---|
| Android | Android SDK, Java 17 | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` |
| Linux | `clang cmake ninja-build pkg-config libgtk-3-dev` | `flutter build linux --release` | `build/linux/x64/release/bundle/` |
| Windows | Visual Studio 2022, charge « Développement Desktop en C++ » | `flutter build windows --release` | `build/windows/x64/runner/Release/` |
| macOS | Xcode | `flutter build macos --release` | `build/macos/Build/Products/Release/cisso_academy.app` |

## Limites actuelles

- L'APK est signé avec la clé de débogage générée par Flutter : il s'installe normalement, mais une signature dédiée sera nécessaire pour une publication sur un store.
- Les applications Windows et macOS ne sont pas signées : Windows SmartScreen et macOS Gatekeeper afficheront un avertissement au premier lancement (macOS : clic droit → Ouvrir).
- Pas de version iOS (non demandée).
