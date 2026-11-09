import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Deel een adres (uit Kaarten, Safari of een bericht) met Bekendr om het als locatie toe te voegen.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let model = ShareModel()
        let host = UIHostingController(rootView: ShareView(model: model) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        Task { await model.load(from: extensionContext) }
    }
}

@MainActor
final class ShareModel: ObservableObject {
    @Published var address: String?
    @Published var loading = true

    func load(from context: NSExtensionContext?) async {
        defer { loading = false }
        let providers = (context?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL,
               let text = Self.address(from: url) {
                address = text
                break
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if let url = URL(string: cleaned), url.scheme?.hasPrefix("http") == true, let a = Self.address(from: url) {
                    address = a
                } else if !cleaned.isEmpty {
                    address = String(cleaned.split(separator: "\n").prefix(3).joined(separator: ", ").prefix(140))
                }
                if address != nil { break }
            }
        }
        if let address { SharedStore.pendingAddress = address }
    }

    /// Haalt een adres uit een link van Apple Kaarten of Google Maps.
    static func address(from url: URL) -> String? {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        for key in ["address", "daddr", "q", "query"] {
            if let value = items.first(where: { $0.name == key })?.value, !value.isEmpty {
                return value.replacingOccurrences(of: "+", with: " ")
            }
        }
        return nil
    }
}

struct ShareView: View {
    @ObservedObject var model: ShareModel
    let done: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                BekendrMark(size: 64)
                if model.loading {
                    ProgressView()
                } else if let address = model.address {
                    Text("Adres ontvangen").font(.title3.weight(.bold))
                    Text(address)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Text("Open Bekendr om dit adres als locatie toe te voegen.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Geen adres gevonden").font(.title3.weight(.bold))
                    Text("Deel een adres uit Kaarten of kopieer een adres als tekst.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle("Bekendr")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Klaar", action: done) }
            }
        }
        .tint(Theme.accent)
    }
}
