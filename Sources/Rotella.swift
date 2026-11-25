import CoreFoundation
import CoreGraphics
import Foundation

final class Motore {
    private let marker: Int64 = 0x526f74656c6c61
    private let sorgente = CGEventSource(stateID: .privateState)
    private var tap: CFMachPort?
    private var timer: Timer?
    private var tempo: TimeInterval = 0
    private var verticale = Moto()
    private var orizzontale = Moto()
    private var impostazioni = readSettings()

    func aggiorna() {
        impostazioni = readSettings()
        ferma()
    }

    func installa() {
        let tipi: [CGEventType] = [.scrollWheel, .leftMouseDown, .rightMouseDown, .otherMouseDown, .flagsChanged]
        let mask = tipi.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
                let motore = Unmanaged<Motore>.fromOpaque(context!).takeUnretainedValue()
                return motore.ricevi(type, event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        tap = port
        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
    }

    func verificaTap() {
        if let tap, !CFMachPortIsValid(tap) { self.tap = nil }
        if tap == nil { installa() }
    }

    private func ricevi(_ tipo: CGEventType, _ evento: CGEvent) -> Unmanaged<CGEvent>? {
        let originale = Unmanaged.passUnretained(evento)
        if tipo == .tapDisabledByTimeout || tipo == .tapDisabledByUserInput {
            ferma()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return originale
        }
        if tipo != .scrollWheel {
            ferma()
            return originale
        }
        if evento.getIntegerValueField(.eventSourceUserData) == marker { return originale }
        if !evento.flags.intersection([.maskControl, .maskShift, .maskAlternate, .maskCommand]).isEmpty {
            ferma()
            return originale
        }

        let gesto = evento.getIntegerValueField(.scrollWheelEventScrollPhase) != 0 ||
            evento.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0 ||
            evento.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let inverti = gesto ? impostazioni.invertiTrackpad : impostazioni.invertiMouse
        if gesto || !impostazioni.fluidita {
            ferma()
            if inverti { invertiDelta(evento) }
            return originale
        }

        let x = evento.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let y = evento.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        guard x != 0 || y != 0 else { return originale }
        let ora = ProcessInfo.processInfo.systemUptime
        let segno = inverti ? -1.0 : 1.0
        aggiungi(&verticale, delta: y, segno: segno, ora: ora, impostazioni: impostazioni)
        aggiungi(&orizzontale, delta: x, segno: segno, ora: ora, impostazioni: impostazioni)
        if timer == nil {
            tempo = ora
            let nuovo = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in self?.fotogramma() }
            timer = nuovo
            RunLoop.main.add(nuovo, forMode: .common)
        }
        return nil
    }

    private func aggiungi(_ moto: inout Moto, delta: Int64, segno: Double, ora: TimeInterval, impostazioni: Impostazioni) {
        moto.aggiungi(segno * Double(delta), ora: ora, velocita: impostazioni[.passo],
            accelerazione: impostazioni[.accelerazione], risposta: impostazioni[.velocita])
    }

    private func invertiDelta(_ evento: CGEvent) {
        let campi: [CGEventField] = [
            .scrollWheelEventDeltaAxis1, .scrollWheelEventDeltaAxis2,
            .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis2,
            .scrollWheelEventPointDeltaAxis1, .scrollWheelEventPointDeltaAxis2
        ]
        let valori = campi.map { evento.getIntegerValueField($0) }
        for (campo, valore) in zip(campi, valori) {
            evento.setIntegerValueField(campo, value: -valore)
        }
    }

    private func fotogramma() {
        let ora = ProcessInfo.processInfo.systemUptime
        let intervallo = ora - tempo
        tempo = ora
        if intervallo > 0.10 {
            ferma()
            return
        }
        let y = verticale.avanza(intervallo, rallentamento: impostazioni[.durata])
        let x = orizzontale.avanza(intervallo, rallentamento: impostazioni[.durata])
        if x != 0 || y != 0, let evento = CGEvent(scrollWheelEvent2Source: sorgente,
            units: .pixel, wheelCount: 2, wheel1: Int32(clamping: y), wheel2: Int32(clamping: x), wheel3: 0) {
            evento.setIntegerValueField(.eventSourceUserData, value: marker)
            evento.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            evento.post(tap: .cgSessionEventTap)
        }
        if !verticale.attivo && !orizzontale.attivo {
            timer?.invalidate()
            timer = nil
        }
    }

    private func ferma() {
        timer?.invalidate()
        timer = nil
        verticale = Moto()
        orizzontale = Moto()
    }
}

func avviaMotore() {
    let motore = Motore()
    let centro = DistributedNotificationCenter.default()
    let observer = centro.addObserver(forName: changed, object: nil, queue: .main) { _ in
        motore.aggiorna()
    }
    defer { centro.removeObserver(observer) }
    motore.verificaTap()
    let verifica = Timer(timeInterval: 3, repeats: true) { _ in motore.verificaTap() }
    RunLoop.main.add(verifica, forMode: .common)
    CFRunLoopRun()
}
