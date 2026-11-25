import SwiftUI
import AppKit

struct Pannello: View {
    @State private var impostazioni = readSettings()
    @StateObject private var servizio = Servizio()
    @Environment(\.scenePhase) private var fase

    var body: some View {
        Form {
            sezioneServizio
            Section("Direzione") {
                Toggle("Inverti la direzione del mouse", isOn: $impostazioni.invertiMouse)
                Toggle("Inverti la direzione del trackpad", isOn: $impostazioni.invertiTrackpad)
                Text("Le due opzioni invertono separatamente la direzione di macOS. I gesti di Magic Mouse seguono l’opzione Trackpad.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Rotella del mouse") {
                Toggle("Scorrimento fluido", isOn: $impostazioni.fluidita)
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
                Button("Ripristina valori iniziali") { impostazioni = Impostazioni() }
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
        Section("Servizio di scorrimento") {
            Label(servizio.stato, systemImage: servizio.pronto ? "checkmark.circle.fill" : "info.circle")
            HStack {
                Button("Installa servizio") { servizio.installa() }
                    .disabled(!servizio.puoInstallare)
                Button("Disinstalla servizio") { servizio.disinstalla() }
                    .disabled(!servizio.puoDisinstallare)
            }
            if servizio.legacy {
                Button("Rimuovi servizio precedente") { servizio.rimuoviPrecedente() }
            }
            if servizio.serveApprovazione {
                Button("Apri elementi login") { servizio.apriElementiLogin() }
            }
            if !servizio.accessibilita {
                Button("Autorizza in Accessibilità") { servizio.apriAccessibilita() }
            }
            if let errore = servizio.errore {
                Text(errore).foregroundStyle(.red)
            }
            Text("Il servizio continua a funzionare quando chiudi Rotella.")
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
