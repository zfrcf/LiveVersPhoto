@preconcurrency import Photos

/// Convertit UNE Live Photo en photo fixe.
///
/// Il n'existe pas d'API publique pour retirer la vidéo « sur place » : on crée
/// donc une nouvelle photo à partir de la seule ressource image, en recopiant
/// les informations de l'originale (date, lieu, favori, albums). La suppression
/// de l'originale est faite plus tard, par le ViewModel, en un appel groupé.
struct LivePhotoConverter {

    /// Petite boîte pour récupérer l'identifiant créé dans le bloc `performChanges`.
    private final class Box: @unchecked Sendable {
        var identifier: String?
    }

    /// Crée la copie fixe et renvoie son identifiant.
    /// - Throws: `ConversionError` ; l'originale n'est jamais modifiée.
    func convert(_ asset: PHAsset) async throws -> ConvertedItem {
        let resources = PHAssetResource.assetResources(for: asset)

        // 1. Choix de la ressource image.
        //    - Photo retouchée : `.fullSizePhoto` est le rendu AVEC les retouches
        //      (sinon la copie reviendrait à l'image d'avant retouche).
        //    - Sinon : `.photo`, le fichier d'origine (HEIC/JPEG) avec tout son EXIF.
        //    Les ressources `.pairedVideo` / `.fullSizePairedVideo` sont ignorées.
        guard let photoResource =
                resources.first(where: { $0.type == .fullSizePhoto })
                ?? resources.first(where: { $0.type == .photo })
        else {
            throw ConversionError.ressourcePhotoIntrouvable
        }

        let videoBytes = resources
            .filter { $0.type == .pairedVideo || $0.type == .fullSizePairedVideo }
            .reduce(Int64(0)) { $0 + Self.fileSize(of: $1) }

        // 2. Extraction vers un fichier temporaire (jamais toute l'image en mémoire).
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileName = photoResource.originalFilename.isEmpty
            ? "photo.heic" : photoResource.originalFilename
        let fileURL = folder.appendingPathComponent(fileName)
        // Nettoyage dans tous les cas (succès, erreur, annulation).
        defer { try? FileManager.default.removeItem(at: folder) }

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true   // télécharge depuis iCloud si besoin
            try await PHAssetResourceManager.default()
                .writeData(for: photoResource, toFile: fileURL, options: options)
        } catch {
            throw ConversionError.extractionEchouee(error.localizedDescription)
        }

        try Task.checkCancellation()

        // 3. Albums de l'utilisateur contenant l'originale (pour y ranger la copie).
        let albums = Self.userAlbums(containing: asset)

        // 4. Création de la photo fixe : une seule ressource `.photo`, aucune vidéo.
        let box = Box()
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let creationOptions = PHAssetResourceCreationOptions()
                creationOptions.originalFilename = fileName
                creationOptions.uniformTypeIdentifier = photoResource.uniformTypeIdentifier
                // Les octets du fichier sont copiés tels quels : l'EXIF est intact.
                request.addResource(with: .photo, fileURL: fileURL, options: creationOptions)

                request.creationDate = asset.creationDate
                request.location = asset.location
                request.isFavorite = asset.isFavorite
                request.isHidden = asset.isHidden

                guard let placeholder = request.placeholderForCreatedAsset else { return }
                box.identifier = placeholder.localIdentifier
                for album in albums {
                    PHAssetCollectionChangeRequest(for: album)?
                        .addAssets([placeholder] as NSArray)
                }
            }
        } catch {
            throw ConversionError.creationEchouee(error.localizedDescription)
        }

        // 5. Vérification : la copie existe bien et n'est plus une Live Photo.
        //    Sans cette preuve, l'originale ne sera jamais proposée à la suppression.
        guard let newID = box.identifier,
              let created = PHAsset.fetchAssets(withLocalIdentifiers: [newID], options: nil).firstObject,
              !created.mediaSubtypes.contains(.photoLive)
        else {
            throw ConversionError.copieNonVerifiee
        }

        return ConvertedItem(originalID: asset.localIdentifier, newID: newID, videoBytes: videoBytes)
    }

    // MARK: Outils

    /// Albums créés par l'utilisateur qui contiennent la photo et acceptent des ajouts.
    private static func userAlbums(containing asset: PHAsset) -> [PHAssetCollection] {
        let result = PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: nil)
        var albums: [PHAssetCollection] = []
        result.enumerateObjects { collection, _, _ in
            if collection.canPerform(.addContent) { albums.append(collection) }
        }
        return albums
    }

    /// Taille d'une ressource. Photos n'expose pas cette valeur publiquement :
    /// on lit la propriété interne `fileSize` (d'où le mot « estimé » dans l'interface).
    private static func fileSize(of resource: PHAssetResource) -> Int64 {
        guard resource.responds(to: NSSelectorFromString("fileSize")),
              let number = resource.value(forKey: "fileSize") as? NSNumber
        else { return 0 }
        return number.int64Value
    }
}
