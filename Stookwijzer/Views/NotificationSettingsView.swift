import SwiftUI

struct NotificationSettingsView: View {
    @Environment(PushManager.self) private var push
    @Environment(PlaceStore.self) private var places
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var push = push

        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: Binding(
                        get: { push.isEnabled },
                        set: { value in Task { await push.setEnabled(value) } }
                    )) {
                        Label("Pushmeldingen", systemImage: "bell.badge.fill")
                    }
                    .tint(Theme.ember)
                } footer: {
                    Text("Je krijgt een melding zodra de stookcode voor een van je plaatsen verandert. We controleren elk uur.")
                }

                if push.authorizationDenied {
                    Section {
                        Text("Meldingen staan uit voor Stookwijzer in de iOS-instellingen.")
                        Button("Open Instellingen") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                }

                if push.isEnabled {
                    Section("Wanneer") {
                        Picker("Melding bij", selection: $push.threshold) {
                            HStack {
                                Circle().fill(AdviceCode.orange.color).frame(width: 10, height: 10)
                                Circle().fill(AdviceCode.red.color).frame(width: 10, height: 10)
                                Text("Code oranje en rood")
                            }
                            .tag(AdviceCode.orange)
                            HStack {
                                Circle().fill(AdviceCode.red.color).frame(width: 10, height: 10)
                                Text("Alleen code rood")
                            }
                            .tag(AdviceCode.red)
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                        .onChange(of: push.threshold) { push.settingsChanged() }

                        Toggle("Melding als het weer code geel wordt", isOn: $push.notifyAllClear)
                            .tint(Theme.ember)
                            .onChange(of: push.notifyAllClear) { push.settingsChanged() }
                    }

                    Section {
                        if places.all.isEmpty {
                            Text("Nog geen plaatsen").foregroundStyle(.secondary)
                        }
                        ForEach(places.all) { place in
                            PlaceRow(place: place)
                        }
                    } header: {
                        Text("Plaatsen")
                    } footer: {
                        Text("Locaties worden afgerond op ongeveer 1 km naar de meldingsserver gestuurd en alleen gebruikt voor het stookadvies.")
                    }

                    Section {
                        HStack {
                            Text("Status")
                            Spacer()
                            if push.isSyncing {
                                ProgressView()
                            } else if let error = push.lastError {
                                Text(error).foregroundStyle(.red).multilineTextAlignment(.trailing)
                            } else if let synced = push.lastSynced {
                                Text("Aangemeld \(NL.time(synced))").foregroundStyle(.secondary)
                            } else {
                                Text("Wachten op Apple…").foregroundStyle(.secondary)
                            }
                        }
                        .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Meldingen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                }
            }
        }
    }
}
