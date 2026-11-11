import Foundation

// MARK: - Erreurs

/// Erreurs possibles pendant la conversion d'une Live Photo.
enum ConversionError: LocalizedError {
    case ressourcePhotoIntrouvable
    case extractionEchouee(String)
    case creationEchouee(String)
    case copieNonVerifiee

    var errorDescription: String? {
        switch self {
        case .ressourcePhotoIntrouvable:
            return "Aucune image fixe trouvée dans cette Live Photo."
        case .extractionEchouee(let detail):
            return "Impossible de récupérer l'image (iCloud ou stockage) : \(detail)"
        case .creationEchouee(let detail):
            return "Impossible de créer la photo fixe : \(detail)"
        case .copieNonVerifiee:
            return "La copie n'a pas pu être vérifiée ; l'originale est conservée."
        }
    }
}

// MARK: - Résultats

/// Résultat de la conversion réussie d'une Live Photo.
struct ConvertedItem: Sendable {
    /// Identifiant de la Live Photo d'origine.
    let originalID: String
    /// Identifiant de la nouvelle photo fixe.
    let newID: String
    /// Taille (estimée) de la partie vidéo, en octets.
    let videoBytes: Int64
}

/// Échec sur une photo, affiché dans le résumé.
struct ConversionFailure: Identifiable, Sendable {
    let id: String          // identifiant de la Live Photo
    let dateText: String    // date de prise de vue, pour la retrouver
    let message: String
}

/// Ce qu'il est advenu des originales à la fin.
enum DeletionOutcome: Sendable, Equatable {
    case notRequested              // option désactivée
    case nothingToDelete           // option activée mais aucune conversion réussie
    case deleted(Int)              // originales envoyées dans « Supprimées récemment »
    case refused                   // l'utilisateur a refusé la confirmation système
    case failed(String)            // erreur système
}

/// Bilan affiché sur l'écran de résumé.
struct ConversionSummary: Sendable {
    var requested = 0
    var converted = 0
    var failures: [ConversionFailure] = []
    var cancelled = false
    var deletion: DeletionOutcome = .notRequested
    /// Taille cumulée des vidéos des Live Photos converties.
    var videoBytes: Int64 = 0

    /// Espace réellement récupérable : seulement si les originales ont été supprimées.
    var freedBytes: Int64 {
        if case .deleted = deletion { return videoBytes }
        return 0
    }
}

// MARK: - Progression

struct ConversionProgress: Sendable, Equatable {
    var done = 0
    var total = 0
    var failed = 0

    var fraction: Double {
        total == 0 ? 0 : Double(done) / Double(total)
    }
}

// MARK: - Mise en forme

enum Format {
    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    static func date(_ date: Date?) -> String {
        guard let date else { return "date inconnue" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    /// « 1 Live Photo » / « 12 Live Photos ».
    static func livePhotos(_ count: Int) -> String {
        count <= 1 ? "\(count) Live Photo" : "\(count) Live Photos"
    }
}
