import Foundation

/// Zet WGS84 (lat/lon) om naar Rijksdriehoekscoördinaten (EPSG:28992).
/// Benaderingsformule van Schreutelkamp & Strang van Hees — nauwkeurig tot op ~1 meter binnen Nederland.
enum RDConverter {
    static func toRD(latitude: Double, longitude: Double) -> (x: Double, y: Double) {
        let x0 = 155_000.0, y0 = 463_000.0
        let phi0 = 52.15517440, lam0 = 5.38720621

        let rp = [0, 1, 2, 0, 1, 3, 1, 0, 2]
        let rq = [1, 1, 1, 3, 0, 1, 3, 2, 3]
        let rpq = [190094.945, -11832.228, -114.221, -32.391, -0.705, -2.34, -0.608, -0.008, 0.148]

        let sp = [1, 0, 2, 1, 3, 0, 2, 1, 0, 1]
        let sq = [0, 2, 0, 2, 0, 1, 2, 1, 4, 4]
        let spq = [309056.544, 3638.893, 73.077, -157.984, 59.788, 0.433, -6.439, -0.032, 0.092, -0.054]

        let dPhi = 0.36 * (latitude - phi0)
        let dLam = 0.36 * (longitude - lam0)

        var x = x0
        var y = y0
        for i in 0..<rpq.count {
            x += rpq[i] * pow(dPhi, Double(rp[i])) * pow(dLam, Double(rq[i]))
        }
        for i in 0..<spq.count {
            y += spq[i] * pow(dPhi, Double(sp[i])) * pow(dLam, Double(sq[i]))
        }
        return (x, y)
    }
}
