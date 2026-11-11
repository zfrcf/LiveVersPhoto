# Live → Photo

App iPhone (SwiftUI, iOS 17+, aucune dépendance) qui crée une copie fixe de
chaque Live Photo, puis propose de supprimer les originales.

## Structure

```
LiveVersPhoto/
├── Package.swift            paquet SwiftPM (iOS 17)
├── xtool.yml                identifiant de l'app + Info.plist à fusionner
├── Info.plist               autorisations Photos, nom affiché
├── installer-outils.sh      installe Swift + xtool sur Linux
└── Sources/LiveVersPhoto/
    ├── LiveVersPhotoApp.swift                 point d'entrée
    ├── Models/ConversionModels.swift          erreurs, résumé, progression
    ├── Services/PhotoLibraryService.swift     autorisation, recherche, suppression groupée
    ├── Services/LivePhotoConverter.swift      conversion d'une Live Photo
    ├── ViewModels/ConversionViewModel.swift   état + boucle par lots de 20
    └── Views/                                 accueil, grille, progression, résumé
```

## Installer sur l'iPhone depuis Linux (compte Apple gratuit)

L'outil utilisé est [xtool](https://github.com/xtool-org/xtool) : il compile,
signe avec votre identifiant Apple et installe, sans Mac.

### Ce qu'il faut savoir avant

- **Le câble USB est obligatoire pour la première installation.** L'iPhone
  n'accepte un ordinateur qu'après « Faire confiance » en USB, et xtool ne voit
  pas les appareils en Wi-Fi (demande ouverte chez eux, n° 134).
- Avec un compte gratuit, l'app fonctionne **7 jours**, puis il faut relancer
  `xtool dev` (câble branché). Pour un outil qu'on utilise une fois, c'est
  suffisant.
- La connexion par mot de passe de xtool passe par des API Apple non
  officielles ; leur documentation conseille un identifiant Apple secondaire.

### Étapes

1. **Outils** (une fois) :

   ```bash
   bash ~/Desktop/LiveVersPhoto/installer-outils.sh
   ```

2. **Xcode.xip** : téléchargez « Xcode 27.1 » sur
   <https://developer.apple.com/download/all/?q=Xcode> (connexion avec votre
   identifiant Apple, plusieurs Go). xtool en extrait seulement le SDK iOS.

3. **Configuration de xtool** (une fois) :

   ```bash
   xtool setup
   ```

   Choisir `1: Password`, saisir identifiant, mot de passe et code à 6 chiffres,
   puis donner le chemin du fichier `Xcode.xip`.

4. **iPhone** : branchez-le en USB, déverrouillez, touchez « Faire confiance ».
   Vérifiez qu'il est vu :

   ```bash
   xtool devices
   ```

5. **Compiler et installer** :

   ```bash
   cd ~/Desktop/LiveVersPhoto && xtool dev
   ```

6. **Sur l'iPhone, la première fois** :
   - Réglages › Confidentialité et sécurité › **Mode développeur** : activer,
     redémarrer (l'option apparaît après la première tentative d'installation) ;
   - Réglages › Général › VPN et gestion de l'appareil : faire confiance à votre
     identifiant Apple ;
   - relancer `xtool dev` si l'installation avait été refusée.

### Et sur un Mac avec Xcode ?

Créer un projet « App » iOS vide, supprimer ses fichiers Swift, y glisser le
dossier `Sources/LiveVersPhoto`, ajouter les deux clés `NSPhotoLibrary…` dans
l'onglet Info, choisir son équipe dans Signing & Capabilities, puis ⌘R.

## Comportement

- Photo retouchée : la copie reprend l'image **avec** les retouches
  (ressource `fullSizePhoto`) ; sinon le fichier d'origine, EXIF intact.
- Conservés : date, lieu, favori, masquage, albums de l'utilisateur.
- Une originale n'est proposée à la suppression que si sa copie a été créée
  **et relue** dans la photothèque. Une seule confirmation système à la fin.
- Sans suppression, relancer « Convertir tout » recrée des copies des mêmes
  Live Photos (elles sont toujours là).
- L'« espace libéré » est la taille des vidéos des originales supprimées ; il
  n'est réellement récupéré qu'après vidage de « Supprimées récemment ».
