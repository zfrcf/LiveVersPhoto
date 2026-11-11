// swift-tools-version: 5.9
// Paquet SwiftPM de l'app. xtool (Linux) l'empaquette en .app à partir du
// produit « library » ci-dessous ; la cible iOS minimale vient de `platforms`.
import PackageDescription

let package = Package(
    name: "LiveVersPhoto",
    defaultLocalization: "fr",
    platforms: [.iOS(.v17)],
    products: [
        // Un seul produit bibliothèque (type automatique) : exigence de xtool.
        .library(name: "LiveVersPhoto", targets: ["LiveVersPhoto"])
    ],
    targets: [
        .target(name: "LiveVersPhoto", path: "Sources/LiveVersPhoto")
    ]
)
