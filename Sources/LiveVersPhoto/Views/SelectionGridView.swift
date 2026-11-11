@preconcurrency import Photos
import SwiftUI
import UIKit

/// Grille pour ne convertir que certaines Live Photos.
struct SelectionGridView: View {
    @EnvironmentObject private var viewModel: ConversionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<String> = []

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if let result = viewModel.fetchResult, result.count > 0 {
                    // LazyVGrid : seules les vignettes visibles sont chargées.
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(0..<result.count, id: \.self) { index in
                            let asset = result.object(at: index)
                            let isSelected = selection.contains(asset.localIdentifier)
                            ThumbnailCell(asset: asset, isSelected: isSelected)
                                .onTapGesture { toggle(asset.localIdentifier) }
                                .accessibilityLabel("Live Photo du \(Format.date(asset.creationDate))")
                                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                } else {
                    ContentUnavailableView("Aucune Live Photo", systemImage: "livephoto.slash")
                        .padding(.top, 80)
                }
            }
            .navigationTitle(selection.isEmpty ? "Choisir des photos" : "\(selection.count) sélectionnée(s)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(selection.isEmpty ? "Tout sélectionner" : "Tout désélectionner") {
                        toggleAll()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let chosen = selection
                    dismiss()
                    viewModel.convert(selection: chosen)
                } label: {
                    Text(selection.isEmpty
                         ? "Convertir la sélection"
                         : "Convertir \(Format.livePhotos(selection.count))")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selection.isEmpty)
                .padding()
                .background(.bar)
            }
        }
    }

    private func toggle(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    private func toggleAll() {
        guard let result = viewModel.fetchResult else { return }
        if selection.isEmpty {
            var ids = Set<String>()
            result.enumerateObjects { asset, _, _ in ids.insert(asset.localIdentifier) }
            selection = ids
        } else {
            selection.removeAll()
        }
    }
}

/// Une vignette carrée avec sa coche de sélection.
private struct ThumbnailCell: View {
    let asset: PHAsset
    let isSelected: Bool
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        Color(.secondarySystemBackground)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, isSelected ? Color.accentColor : Color.black.opacity(0.25))
                    .shadow(radius: 1)
                    .padding(5)
            }
            .overlay {
                if isSelected { Color.accentColor.opacity(0.25) }
            }
            .contentShape(Rectangle())
            .onAppear(perform: load)
            .onDisappear(perform: cancelLoad)
    }

    private func load() {
        guard image == nil else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic   // aperçu rapide puis meilleure qualité
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let side = 120 * displayScale
        // Le gestionnaire rappelle sur le fil principal (requête asynchrone).
        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: side, height: side),
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            if let result { image = result }
        }
    }

    private func cancelLoad() {
        if let requestID { PHImageManager.default().cancelImageRequest(requestID) }
        requestID = nil
    }
}
