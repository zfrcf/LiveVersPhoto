@preconcurrency import Photos
import UIKit

/// Accès à la photothèque : autorisation, recherche des Live Photos, suppression groupée.
/// Ne contient aucun état d'interface (c'est le rôle du ViewModel).
struct PhotoLibraryService {

    // MARK: Autorisation

    /// État actuel de l'autorisation en lecture/écriture.
    var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Affiche la demande système si elle n'a jamais été faite, puis renvoie l'état.
    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    // MARK: Recherche

    /// Toutes les Live Photos visibles par l'app, de la plus récente à la plus ancienne.
    /// Le résultat est paresseux : les PHAsset ne sont chargés qu'à la demande.
    func fetchLivePhotos() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        // mediaSubtypes est un masque de bits : on teste le bit « photoLive ».
        options.predicate = NSPredicate(
            format: "(mediaSubtypes & %d) != 0",
            PHAssetMediaSubtype.photoLive.rawValue
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeHiddenAssets = false
        return PHAsset.fetchAssets(with: .image, options: options)
    }

    /// Identifiants de toutes les photos d'un résultat de recherche.
    func identifiers(of result: PHFetchResult<PHAsset>) -> [String] {
        var ids: [String] = []
        ids.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in ids.append(asset.localIdentifier) }
        return ids
    }

    /// Recharge des PHAsset à partir de leurs identifiants (utilisé lot par lot).
    func assets(withIdentifiers ids: [String]) -> [PHAsset] {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var byID: [String: PHAsset] = [:]
        result.enumerateObjects { asset, _, _ in byID[asset.localIdentifier] = asset }
        // On respecte l'ordre demandé ; les photos disparues entre-temps sont ignorées.
        return ids.compactMap { byID[$0] }
    }

    // MARK: Suppression

    /// Supprime les originales en UN SEUL appel : iOS n'affiche qu'une confirmation.
    /// Lève une erreur si l'utilisateur refuse (PHPhotosError.userCancelled).
    func deleteAssets(withIdentifiers ids: [String]) async throws -> Int {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        let count = assets.count
        guard count > 0 else { return 0 }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
        return count
    }

    // MARK: Réglages

    /// Ouvre la page de l'app dans Réglages (pour changer l'accès aux photos).
    @MainActor
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
