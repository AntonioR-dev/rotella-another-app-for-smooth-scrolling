import CoreFoundation
import Foundation

enum Parametro: String, CaseIterable, Identifiable {
    case passo, accelerazione, durata, velocita
    var id: Self { self }

    var dati: (titolo: String, intervallo: ClosedRange<Double>, iniziale: Double, passo: Double, unita: String, aiuto: String) {
        switch self {
        case .passo: return ("Speed", 8...80, 32, 1, "px", "Distance traveled per slow wheel step.")
        case .accelerazione: return ("Acceleration", 1...8, 2.5, 0.1, "×", "Increases the distance when you turn the wheel faster.")
        case .durata: return ("Deceleration", 60...380, 170, 5, "ms", "Higher values make scrolling coast longer.")
        case .velocita: return ("Initial Response", 0.6...2, 1, 0.05, "×", "Higher values deliver more movement at the start.")
        }
    }
}

let settingsDomain = "local.rotella.preferences" as CFString
let changed = Notification.Name("local.rotella.preferences.changed")

struct Impostazioni: Equatable {
    var valori = Dictionary(uniqueKeysWithValues: Parametro.allCases.map { ($0, $0.dati.iniziale) })
    var invertiMouse = true
    var invertiTrackpad = false
    var fluidita = true

    subscript(_ p: Parametro) -> Double {
        get { valori[p, default: p.dati.iniziale] }
        set { valori[p] = newValue }
    }

    func salva() {
        for (p, v) in valori {
            CFPreferencesSetAppValue(p.rawValue as CFString, NSNumber(value: v), settingsDomain)
        }
        for (chiave, valore) in [("invertiMouse", invertiMouse), ("invertiTrackpad", invertiTrackpad), ("fluidita", fluidita)] {
            CFPreferencesSetAppValue(chiave as CFString, NSNumber(value: valore), settingsDomain)
        }
        CFPreferencesAppSynchronize(settingsDomain)
        DistributedNotificationCenter.default().postNotificationName(changed, object: nil, userInfo: nil, deliverImmediately: true)
    }
}

func readSettings() -> Impostazioni {
    CFPreferencesAppSynchronize(settingsDomain)
    var risultato = Impostazioni()
    for p in Parametro.allCases {
        if let valore = (CFPreferencesCopyAppValue(p.rawValue as CFString, settingsDomain) as? NSNumber)?.doubleValue,
           valore.isFinite {
            risultato[p] = min(p.dati.intervallo.upperBound, max(p.dati.intervallo.lowerBound, valore))
        }
    }
    risultato.invertiMouse = (CFPreferencesCopyAppValue("invertiMouse" as CFString, settingsDomain) as? NSNumber)?.boolValue ?? risultato.invertiMouse
    risultato.invertiTrackpad = (CFPreferencesCopyAppValue("invertiTrackpad" as CFString, settingsDomain) as? NSNumber)?.boolValue ?? risultato.invertiTrackpad
    risultato.fluidita = (CFPreferencesCopyAppValue("fluidita" as CFString, settingsDomain) as? NSNumber)?.boolValue ?? risultato.fluidita
    return risultato
}
