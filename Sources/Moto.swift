import Foundation

/// Due stadi esponenziali. Gli impulsi si sommano nello stesso stato,
/// con velocità iniziale moderata e una coda che si esaurisce progressivamente.
struct Moto {
    private var attesa = 0.0
    private var coda = 0.0
    private var frazione = 0.0
    private var ultimoScatto: TimeInterval?
    private var direzione = 0.0
    private var cadenza = 0.0

    var attivo: Bool { attesa != 0 || coda != 0 }

    mutating func aggiungi(_ delta: Double, ora: TimeInterval, velocita: Double, accelerazione: Double, risposta: Double) {
        guard delta != 0 else { return }
        let segno = delta < 0 ? -1.0 : 1.0
        if segno != direzione { self = Moto() }
        if let ultimoScatto {
            let intervallo = ora - ultimoScatto
            let ritmo = min(1, max(0, (0.18 - intervallo) / 0.15))
            cadenza = intervallo >= 0.18 ? 0 : 0.5 * cadenza + 0.5 * ritmo
        }
        ultimoScatto = ora
        direzione = segno

        // Il delta a righe può essere già accelerato da macOS.
        let intensita = min(2.5, 1 + 0.2 * (abs(delta) - 1))
        let distanza = segno * intensita * velocita * (1 + (accelerazione - 1) * cadenza * cadenza)
        let quotaIniziale = risposta * 0.14
        attesa += distanza * (1 - quotaIniziale)
        coda += distanza * quotaIniziale
    }

    mutating func avanza(_ intervallo: TimeInterval, rallentamento: Double) -> Int {
        guard attivo, intervallo > 0 else { return 0 }
        let prima = attesa + coda
        let tempo = intervallo / (rallentamento / 5_000)
        let fattore = exp(-tempo)
        coda = (coda + attesa * tempo) * fattore
        attesa *= fattore
        if abs(attesa + coda) < 0.25 {
            attesa = 0
            coda = 0
        }
        let movimento = prima - (attesa + coda) + frazione
        let pixel = Int(movimento.rounded())
        frazione = movimento - Double(pixel)
        return pixel
    }
}
