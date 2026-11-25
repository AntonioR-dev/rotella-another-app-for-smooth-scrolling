import AppKit
import ApplicationServices
import ServiceManagement
import SwiftUI

@MainActor
final class Servizio: ObservableObject {
    private static let nomePlist = "local.rotella.agent.plist"
    private let agente = SMAppService.agent(plistName: Servizio.nomePlist)
    private var plistIncluso: Bool {
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchAgents")
            .appendingPathComponent(Self.nomePlist)
        return FileManager.default.isReadableFile(atPath: url.path)
    }
    private let jobLegacy = "gui/\(getuid())/local.rotella.scroll"
    private var plistLegacy: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/local.rotella.scroll.plist")
    }

    @Published private var registrazione: SMAppService.Status = .notRegistered
    @Published private(set) var accessibilita = false
    @Published private(set) var legacy = false
    @Published private(set) var errore: String?

    var puoInstallare: Bool {
        !legacy && plistIncluso && (registrazione == .notRegistered || registrazione == .notFound)
    }
    var puoDisinstallare: Bool { registrazione == .enabled || serveApprovazione }
    var serveApprovazione: Bool { registrazione == .requiresApproval }
    var pronto: Bool { registrazione == .enabled && accessibilita && !legacy }

    var stato: String {
        if legacy { return "È presente il servizio di Rotella 2" }
        switch registrazione {
        case .enabled: return accessibilita ? "Servizio abilitato" : "Serve il permesso di Accessibilità"
        case .requiresApproval: return "Consenti Rotella negli elementi login"
        case .notRegistered: return "Servizio non installato"
        case .notFound:
            return plistIncluso ? "Servizio da registrare in macOS" : "File del servizio assente dall’app"
        @unknown default: return "Stato del servizio sconosciuto"
        }
    }

    func aggiorna() {
        registrazione = agente.status
        accessibilita = AXIsProcessTrusted()
        legacy = FileManager.default.fileExists(atPath: plistLegacy.path) ||
            ((try? launchctl("print")) == 0)
    }

    func controllaPeriodicamente() async {
        while !Task.isCancelled {
            aggiorna()
            try? await Task.sleep(for: .seconds(2))
        }
    }

    func installa() {
        aggiorna()
        guard puoInstallare else { return }
        esegui { try agente.register() }
    }

    func disinstalla() {
        aggiorna()
        guard puoDisinstallare else { return }
        esegui { try agente.unregister() }
    }

    func apriElementiLogin() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func apriAccessibilita() {
        let opzioni = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(opzioni as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func rimuoviPrecedente() {
        esegui {
            if try launchctl("print") == 0 {
                guard try launchctl("bootout") == 0 || launchctl("print") != 0 else {
                    throw NSError(domain: "Rotella", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Impossibile arrestare il servizio precedente."
                    ])
                }
            }
            if FileManager.default.fileExists(atPath: plistLegacy.path) {
                try FileManager.default.trashItem(at: plistLegacy, resultingItemURL: nil)
            }
        }
    }

    private func esegui(_ azione: () throws -> Void) {
        errore = nil
        do {
            try azione()
        } catch {
            let dettaglio = error as NSError
            errore = "\(dettaglio.localizedDescription) (\(dettaglio.domain), \(dettaglio.code))"
        }
        aggiorna()
    }

    private func launchctl(_ verb: String) throws -> Int32 {
        let processo = Process()
        processo.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        processo.arguments = [verb, jobLegacy]
        processo.standardOutput = FileHandle.nullDevice
        processo.standardError = FileHandle.nullDevice
        try processo.run()
        processo.waitUntilExit()
        return processo.terminationStatus
    }
}
