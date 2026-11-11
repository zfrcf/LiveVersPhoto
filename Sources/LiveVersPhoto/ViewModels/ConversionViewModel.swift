@preconcurrency import Photos
import SwiftUI
import UIKit

/// État et logique de l'app (MVVM). Tout ce qui est publié est lu par les vues.
@MainActor
final class ConversionViewModel: ObservableObject {

    /// Écran affiché.
    enum Phase: Equatable {
        case checking       // autorisation pas encore connue
        case denied         // refusée ou restreinte → bouton Réglages
        case ready          // écran principal
        case converting     // barre de progression
        case finished       // résumé
    }

    // MARK: État publié

    @Published private(set) var phase: Phase = .checking
    /// Accès limité : l'app ne voit que les photos choisies par l'utilisateur.
    @Published private(set) var isLimited = false
    @Published private(set) var liveCount = 0
    @Published private(set) var progress = ConversionProgress()
    @Published private(set) var summary = ConversionSummary()
    @Published private(set) var isCancelling = false
    /// Option « Supprimer les originales après conversion » (désactivée par défaut).
    @Published var deleteOriginals = false

    /// Résultat de recherche, utilisé par la grille de sélection.
    private(set) var fetchResult: PHFetchResult<PHAsset>?

    // MARK: Dépendances

    private let library = PhotoLibraryService()
    private let converter = LivePhotoConverter()
    private var conversionTask: Task<Void, Never>?

    /// Nombre de photos traitées par lot (limite les pics de mémoire).
    private let batchSize = 20

    // MARK: Autorisation et chargement

    /// Appelé au lancement et à chaque retour au premier plan.
    func start() async {
        guard phase != .converting, phase != .finished else { return }
        var status = library.authorizationStatus
        if status == .notDetermined {
            status = await library.requestAuthorization()
        }
        switch status {
        case .authorized:
            isLimited = false
            reload()
            phase = .ready
        case .limited:
            isLimited = true
            reload()
            phase = .ready
        default: // .denied, .restricted
            phase = .denied
        }
    }

    /// Recompte les Live Photos.
    func reload() {
        let result = library.fetchLivePhotos()
        fetchResult = result
        liveCount = result.count
    }

    func openSettings() {
        library.openSettings()
    }

    // MARK: Conversion

    /// Convertit toutes les Live Photos visibles.
    func convertAll() {
        guard let fetchResult else { return }
        startConversion(ids: library.identifiers(of: fetchResult))
    }

    /// Convertit seulement les photos choisies dans la grille.
    func convert(selection: Set<String>) {
        guard let fetchResult else { return }
        // On garde l'ordre de la photothèque.
        let ids = library.identifiers(of: fetchResult).filter { selection.contains($0) }
        startConversion(ids: ids)
    }

    /// Demande l'arrêt : la photo en cours se termine, puis on passe au résumé.
    func cancel() {
        isCancelling = true
        conversionTask?.cancel()
    }

    /// Retour à l'écran principal après le résumé.
    func backToHome() {
        reload()
        phase = .ready
    }

    private func startConversion(ids: [String]) {
        guard !ids.isEmpty, phase == .ready else { return }
        let shouldDelete = deleteOriginals
        progress = ConversionProgress(done: 0, total: ids.count, failed: 0)
        summary = ConversionSummary(requested: ids.count)
        isCancelling = false
        phase = .converting
        // L'écran reste allumé : iOS suspend l'app si elle passe en arrière-plan.
        UIApplication.shared.isIdleTimerDisabled = true

        conversionTask = Task { [weak self] in
            await self?.run(ids: ids, deleteOriginals: shouldDelete)
        }
    }

    /// Boucle principale : lots de `batchSize`, une photo à la fois.
    private func run(ids: [String], deleteOriginals: Bool) async {
        var converted: [ConvertedItem] = []
        var failures: [ConversionFailure] = []
        var cancelled = false

        batches: for start in stride(from: 0, to: ids.count, by: batchSize) {
            let batchIDs = Array(ids[start..<min(start + batchSize, ids.count)])
            // Les PHAsset ne vivent que le temps du lot.
            let assets = library.assets(withIdentifiers: batchIDs)

            // Photos disparues depuis le comptage (supprimées ailleurs) : comptées en échec.
            let found = Set(assets.map(\.localIdentifier))
            for missing in batchIDs where !found.contains(missing) {
                failures.append(ConversionFailure(
                    id: missing, dateText: "—",
                    message: "Photo introuvable (supprimée entre-temps)."))
                progress.done += 1
                progress.failed += 1
            }

            for asset in assets {
                if Task.isCancelled { cancelled = true; break batches }
                do {
                    converted.append(try await converter.convert(asset))
                } catch is CancellationError {
                    cancelled = true
                    break batches
                } catch {
                    failures.append(ConversionFailure(
                        id: asset.localIdentifier,
                        dateText: Format.date(asset.creationDate),
                        message: error.localizedDescription))
                    progress.failed += 1
                }
                progress.done += 1
            }
            // Laisse respirer l'interface et la mémoire entre deux lots.
            await Task.yield()
        }

        // Suppression groupée : UNIQUEMENT les originales dont la copie est vérifiée.
        // En cas d'annulation, on la propose aussi pour ne pas laisser de doublons ;
        // la confirmation système laisse de toute façon le dernier mot à l'utilisateur.
        var deletion = DeletionOutcome.notRequested
        if deleteOriginals {
            if converted.isEmpty {
                deletion = .nothingToDelete
            } else {
                do {
                    let count = try await library.deleteAssets(withIdentifiers: converted.map(\.originalID))
                    deletion = .deleted(count)
                } catch let error as PHPhotosError where error.code == .userCancelled {
                    deletion = .refused
                } catch {
                    deletion = .failed(error.localizedDescription)
                }
            }
        }

        summary = ConversionSummary(
            requested: ids.count,
            converted: converted.count,
            failures: failures,
            cancelled: cancelled,
            deletion: deletion,
            videoBytes: converted.reduce(0) { $0 + $1.videoBytes })

        UIApplication.shared.isIdleTimerDisabled = false
        isCancelling = false
        conversionTask = nil
        reload()
        phase = .finished
    }
}
