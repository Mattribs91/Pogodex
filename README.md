# Pogodex

<p align="center">
  <img src="https://img.shields.io/badge/iOS-16.0+-blue.svg" alt="iOS 16.0+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange.svg" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/SwiftUI-Native-green.svg" alt="SwiftUI">
</p>

**Pogodex** est une application iOS native développée en SwiftUI pour suivre votre collection Pokémon GO. Elle permet de gérer facilement vos captures, y compris les formes Shiny, les Costumes, les Pokémon Chanceux, les formes Régionales, et bien plus encore.

## ✨ Fonctionnalités Principales

*   **Suivi de Collection Complet** :
    *   Marquez vos Pokémon comme **Capturés** (Standard) ou **Shiny**.
    *   Gestion des quantités (compteur de captures multiples).
    *   Support des **Pokémon Chanceux** (Lucky) avec indicateur visuel (bordure dorée).
    *   Indicateurs visuels pour les Pokémon non sortis (Unreleased) ou Légendaires/Fabuleux.

*   **Gestion des Variantes Avancée** :
    *   Support de toutes les formes : **Régionales** (Alola, Galar, Hisui, Paldea), **Costumes** (Chapeaux, Événements), **Méga-Évolutions**, **Gigantamax** et **Dynamax**.
    *   **Noms Localisés Propres** : Traduction automatique des noms techniques (ex: "PIKACHU_POP_STAR" → "Starteur") pour une interface plus propre.
    *   **Bouton "Standard" Intelligent** : Capturez la forme de base directement depuis l'en-tête, sans avoir à chercher dans la grille des variantes.

*   **☁️ Synchronisation iCloud** :
    *   Sauvegarde automatique de votre progression via `NSUbiquitousKeyValueStore`.
    *   Retrouvez votre collection sur tous vos appareils Apple instantanément.

*   **🌍 Multilingue** :
    *   Support complet de 7 langues (Français, Anglais, Allemand, Espagnol, Italien, Japonais, Coréen).
    *   Changement de langue à la volée depuis les réglages de l'application.

*   **Interface Moderne & Fluide** :
    *   Design inspiré de l'esthétique iOS (Glassmorphism, animations fluides).
    *   **Mode Sombre** et couleurs dynamiques basées sur le type du Pokémon.
    *   **Images Haute Résolution** (Rendus 3D Home) pour les formes principales.
    *   **Chaîne d'Évolutions Modernisée** (rail visuel) et réactive au mode Shiny.

## 🚀 Performance & Architecture

L'application a été optimisée pour gérer une grande quantité de données graphiques (sprites, icônes) tout en maintenant une faible empreinte mémoire (RAM) et une fluidité constante (60fps).

### 1. Gestion de la Mémoire (RAM)
*   **Lazy Loading Strict** : Utilisation d'une seule `LazyVGrid` plate. Cela permet à SwiftUI de libérer la mémoire de *chaque cellule* individuellement dès qu'elle quitte l'écran.
*   **Image Downsampling** : Le décodage des images se fait à la taille exacte d'affichage (thumbnail) plutôt qu'à la taille réelle du fichier, réduisant drastiquement l'allocation mémoire.

### 2. Caching & Réseau
*   **NSCache vs URLCache** : Utilisation d'un `NSCache` personnalisé pour stocker les objets `UIImage` décodés (coûteux en CPU) plutôt que les données brutes.
*   **Concurrency Swift 6** : Utilisation stricte de `@MainActor` et `Task` pour garantir la sécurité des threads lors du téléchargement asynchrone des images.
*   **Annulation des Tâches** : Les tâches de téléchargement sont automatiquement annulées via `.task { }` si la vue disparaît avant la fin du chargement.

## 🛠 Installation & Développement

1.  Clonez ce dépôt : `git clone https://github.com/votre-nom/PogoTracker.git`
2.  Ouvrez `PogoTracker.xcodeproj` dans Xcode 15+.
3.  Sélectionnez votre simulateur ou votre iPhone.
4.  Cliquez sur **Run** (Cmd + R).

## 📁 Structure du Projet

*   `Models/` : Structures de données (`Pokemon`, `AssetForm`) et logique de traduction (`PokemonTranslation`).
*   `ViewModels/` : Gestion de l'état (`PogodexViewModel`), chargement des données API, logique de persistance et synchronisation iCloud.
*   `Views/` : Interface utilisateur SwiftUI (`PokemonDetailView`, `PokemonCell`, `ContentView`, `SettingsView`, `CreditsView`).
*   `Assets.xcassets/` : Icônes de types personnalisées, couleurs d'accentuation et icône de l'application.

## ⚖️ Mentions Légales & Crédits

*   **Avertissement** : Pokémon et Pokémon GO sont des marques déposées de The Pokémon Company, Niantic, Inc., et Nintendo. Cette application est un outil non officiel créé par des fans et n'est ni affiliée, ni approuvée, ni sponsorisée par Niantic, The Pokémon Company ou Nintendo. Toutes les images, noms et informations de Pokémon sont utilisés dans le cadre du "Fair Use" à des fins informatives.
*   **Données API** : [pokemon-go-api](https://github.com/pokemon-go-api/pokemon-go-api)
*   **Artworks & Sprites** : [PokéAPI](https://pokeapi.co/)

---
*Créé avec ❤️ pour la communauté Pokémon GO.*
