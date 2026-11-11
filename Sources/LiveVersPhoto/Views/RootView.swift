import SwiftUI

/// Aiguillage entre les écrans selon la phase du ViewModel.
struct RootView: View {
    @EnvironmentObject private var viewModel: ConversionViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .checking:
                    ProgressView("Vérification de l'accès aux photos…")
                case .denied:
                    PermissionView()
                case .ready:
                    HomeView()
                case .converting:
                    ConversionProgressView()
                case .finished:
                    SummaryView()
                }
            }
            .navigationTitle("Live → Photo")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await viewModel.start() }
        // Au retour des Réglages (ou de l'app Photos), on revérifie l'accès et le compteur.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.start() }
            }
        }
    }
}

/// Écran affiché quand l'accès à la photothèque est refusé ou restreint.
struct PermissionView: View {
    @EnvironmentObject private var viewModel: ConversionViewModel

    var body: some View {
        ContentUnavailableView {
            Label("Accès aux photos refusé", systemImage: "photo.badge.exclamationmark")
        } description: {
            Text("L'app a besoin d'accéder à toutes vos photos pour trouver les Live Photos et créer leurs copies fixes. Autorisez l'accès dans Réglages › Photos.")
        } actions: {
            Button("Ouvrir les Réglages") { viewModel.openSettings() }
                .buttonStyle(.borderedProminent)
        }
    }
}
