import SwiftUI
import AppKit

struct Pannello: View {
    @State private var impostazioni = readSettings()
    @StateObject private var servizio = Servizio()
    @Environment(\.scenePhase) private var fase

    var body: some View {
        Form {
            sezioneServizio
            Section("Scroll Direction") {
                Toggle("Reverse Mouse Scrolling", isOn: $impostazioni.invertiMouse)
                Toggle("Reverse Trackpad Scrolling", isOn: $impostazioni.invertiTrackpad)
                Text("Each switch reverses the macOS scroll direction independently. Magic Mouse gestures follow the trackpad setting.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Mouse Wheel") {
                Toggle("Smooth Scrolling", isOn: $impostazioni.fluidita)
                ForEach(Parametro.allCases) { p in
                    let dati = p.dati
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(dati.titolo)
                            Spacer()
                            Text(impostazioni[p].formatted(.number.precision(.fractionLength(dati.unita == "×" ? 2 : 0))) + " " + dati.unita)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(get: { impostazioni[p] }, set: { impostazioni[p] = $0 }),
                               in: dati.intervallo, step: dati.passo)
                            .accessibilityLabel(dati.titolo)
                        Text(dati.aiuto).font(.caption).foregroundStyle(.secondary)
                    }
                    .disabled(!impostazioni.fluidita)
                }
            }
            Section {
                Button("Restore Defaults") { impostazioni = Impostazioni() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 530, height: 690)
        .task { await servizio.controllaPeriodicamente() }
        .onChange(of: fase) { nuova in
            if nuova == .active {
                servizio.aggiorna()
                impostazioni = readSettings()
            }
        }
        .onChange(of: impostazioni) { valore in valore.salva() }
    }
    private var sezioneServizio: some View {
        Section("Background Service") {
            Label(servizio.stato, systemImage: servizio.pronto ? "checkmark.circle.fill" : "info.circle")
            HStack {
                Button("Install Service") { servizio.installa() }
                    .disabled(!servizio.puoInstallare)
                Button("Uninstall Service") { servizio.disinstalla() }
                    .disabled(!servizio.puoDisinstallare)
            }
            if servizio.legacy {
                Button("Remove Previous Service") { servizio.rimuoviPrecedente() }
            }
            if servizio.serveApprovazione {
                Button("Open Login Items") { servizio.apriElementiLogin() }
            }
            if !servizio.accessibilita {
                Button("Open Accessibility Settings") { servizio.apriAccessibilita() }
            }
            if let errore = servizio.errore {
                Text(errore).foregroundStyle(.red)
            }
            Text("The service keeps working after you quit Rotella.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

final class Delegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct RotellaApp: App {
    @NSApplicationDelegateAdaptor(Delegate.self) var delegate
    var body: some Scene {
        Window("Rotella", id: "rotella") { Pannello() }
            .windowResizability(.contentSize)
    }
}
