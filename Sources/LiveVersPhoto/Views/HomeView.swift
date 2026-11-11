import SwiftUI

/// Écran principal : compteur, option de suppression, boutons de conversion.
struct HomeView: View {
    @EnvironmentObject private var viewModel: ConversionViewModel
    @State private var showSelection = false
    @State private var confirmAll = false

    var body: some View {
        List {
            // Compteur
            Section {
                VStack(spacing: 6) {
                    Image(systemName: "livephoto")
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                    Text("\(viewModel.liveCount)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(viewModel.liveCount <= 1 ? "Live Photo trouvée" : "Live Photos trouvées")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            }

            // Bandeau « accès limité »
            if viewModel.isLimited {
                Section {
                    Label("Accès limité : seules les photos que vous avez autorisées sont comptées.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button("Autoriser toutes les photos dans Réglages") {
                        viewModel.openSettings()
                    }
                }
            }

            // Option de suppression
            Section {
                Toggle("Supprimer les originales après conversion", isOn: $viewModel.deleteOriginals)
            } footer: {
                if viewModel.deleteOriginals {
                    Text("Une seule confirmation vous sera demandée à la fin. Seules les Live Photos dont la copie a bien été créée sont supprimées ; elles restent 30 jours dans « Supprimées récemment ».")
                } else {
                    Text("Les Live Photos d'origine sont conservées : vous aurez chaque photo en double (la Live et la copie fixe), sans gain de place.")
                }
            }

            // Actions
            Section {
                Button {
                    confirmAll = true
                } label: {
                    Label("Convertir tout", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Button {
                    showSelection = true
                } label: {
                    Label("Choisir des photos…", systemImage: "checkmark.circle")
                }
            } footer: {
                Text("Gardez l'app ouverte pendant la conversion. Les photos stockées dans iCloud sont téléchargées au passage.")
            }
            .disabled(viewModel.liveCount == 0)
        }
        .refreshable { viewModel.reload() }
        .sheet(isPresented: $showSelection) {
            SelectionGridView()
        }
        .confirmationDialog(
            "Convertir \(Format.livePhotos(viewModel.liveCount)) ?",
            isPresented: $confirmAll,
            titleVisibility: .visible
        ) {
            Button("Convertir tout") { viewModel.convertAll() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text(viewModel.deleteOriginals
                 ? "Une copie fixe de chaque photo sera créée, puis la suppression des originales vous sera proposée."
                 : "Une copie fixe de chaque photo sera créée. Les originales ne seront pas touchées.")
        }
    }
}
