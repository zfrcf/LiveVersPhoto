import SwiftUI

/// Écran de progression avec bouton Annuler.
struct ConversionProgressView: View {
    @EnvironmentObject private var viewModel: ConversionViewModel

    var body: some View {
        let progress = viewModel.progress
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "livephoto")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse)

            VStack(spacing: 8) {
                ProgressView(value: progress.fraction)
                    .progressViewStyle(.linear)
                Text("\(progress.done) sur \(progress.total)")
                    .font(.title3.monospacedDigit().weight(.semibold))
                if progress.failed > 0 {
                    Text(progress.failed == 1 ? "1 échec" : "\(progress.failed) échecs")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }

            Text("Gardez l'app ouverte. Les photos iCloud peuvent prendre un moment à télécharger.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button(role: .cancel) {
                viewModel.cancel()
            } label: {
                Text(viewModel.isCancelling ? "Arrêt après la photo en cours…" : "Annuler")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(viewModel.isCancelling)
        }
        .padding(24)
    }
}

/// Écran de résumé : converties, échecs, espace libéré estimé.
struct SummaryView: View {
    @EnvironmentObject private var viewModel: ConversionViewModel

    var body: some View {
        let summary = viewModel.summary
        List {
            Section {
                LabeledContent("Photos converties", value: "\(summary.converted) sur \(summary.requested)")
                LabeledContent("Échecs", value: "\(summary.failures.count)")
                LabeledContent("Espace libéré estimé", value: Format.bytes(summary.freedBytes))
            } header: {
                Text(summary.cancelled ? "Conversion interrompue" : "Conversion terminée")
            } footer: {
                Text(deletionText(summary))
            }

            if !summary.failures.isEmpty {
                Section("Photos non converties (originales conservées)") {
                    ForEach(summary.failures) { failure in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(failure.dateText).font(.subheadline.weight(.medium))
                            Text(failure.message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button("Terminé") { viewModel.backToHome() }
                    .frame(maxWidth: .infinity)
                    .font(.headline)
            }
        }
    }

    /// Phrase expliquant ce qu'il est advenu des originales.
    private func deletionText(_ summary: ConversionSummary) -> String {
        switch summary.deletion {
        case .notRequested:
            return "Les originales ont été conservées, donc aucun espace n'est libéré. Les vidéos de ces Live Photos occupent environ \(Format.bytes(summary.videoBytes))."
        case .nothingToDelete:
            return "Aucune photo convertie : rien n'a été supprimé."
        case .deleted(let count):
            return "\(count) originale(s) déplacée(s) dans « Supprimées récemment ». L'espace sera réellement libéré quand vous viderez cet album dans Photos (ou au bout de 30 jours)."
        case .refused:
            return "Vous avez refusé la suppression : les originales sont conservées, en plus des copies fixes."
        case .failed(let message):
            return "La suppression des originales a échoué (\(message)). Elles sont conservées, en plus des copies fixes."
        }
    }
}
