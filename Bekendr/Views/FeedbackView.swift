import SwiftUI

/// Laat het weten als er iets niet klopt aan een bekendmaking. Komt binnen in het beheer van Bekendr.
struct FeedbackView: View {
    let notice: Notice
    @Environment(\.dismiss) private var dismiss
    @State private var reason: FeedbackReason = .locatie
    @State private var message = ""
    @State private var sending = false
    @State private var error: String?
    @State private var sent = false

    var body: some View {
        NavigationStack {
            Group {
                if sent {
                    ContentUnavailableView {
                        Label("Bedankt!", systemImage: "checkmark.circle.fill")
                    } description: {
                        Text("Je feedback is ontvangen. Daarmee maken we de indeling van Bekendr beter. Je krijgt geen persoonlijk antwoord.")
                    } actions: {
                        Button("Sluiten") { dismiss() }.buttonStyle(.borderedProminent)
                    }
                } else {
                    form
                }
            }
            .navigationTitle("Feedback")
            .inlineTitle()
            .toolbar {
                if !sent {
                    ToolbarItem(placement: .cancellationAction) { Button("Annuleer") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Verstuur") { send() }
                            .disabled(sending || (reason == .anders && message.trimmingCharacters(in: .whitespacesAndNewlines).count < 3))
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 520)
        #endif
        .sensoryFeedback(.success, trigger: sent)
    }

    private var form: some View {
        Form {
            Section {
                Text(notice.title).font(.subheadline.weight(.semibold)).lineLimit(3)
            } header: { Text("Bekendmaking") }

            Section {
                ForEach(FeedbackReason.allCases) { r in
                    Button { reason = r } label: {
                        HStack {
                            Label(r.label, systemImage: r.symbol).foregroundStyle(.primary)
                            Spacer()
                            if reason == r { Image(systemName: "checkmark").foregroundStyle(Theme.accent).fontWeight(.semibold) }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(reason == r ? .isSelected : [])
                }
            } header: { Text("Wat klopt er niet?") }

            Section {
                TextField(reason == .anders ? "Omschrijf wat er niet klopt (verplicht)" : "Toelichting (optioneel)",
                          text: $message, axis: .vertical)
                    .lineLimit(3...8)
            } header: { Text("Toelichting") } footer: {
                Text("Wil je bezwaar maken of een zienswijze indienen? Dat doe je bij de instantie zelf; hoe dat gaat, staat in de officiële publicatie.")
            }

            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
            }
            if sending { Section { HStack { ProgressView(); Text("Versturen…") } } }
        }
        .formStyle(.grouped)
    }

    private func send() {
        sending = true
        error = nil
        Task {
            defer { sending = false }
            do {
                try await FeedbackClient.send(notice: notice, reason: reason, message: message.trimmingCharacters(in: .whitespacesAndNewlines))
                withAnimation { sent = true }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
