import SwiftUI

/// Point d'entrée de l'app.
@main
struct LiveVersPhotoApp: App {
    /// Un seul ViewModel pour toute l'app (état de l'autorisation, de la conversion…).
    @StateObject private var viewModel = ConversionViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
        }
    }
}
