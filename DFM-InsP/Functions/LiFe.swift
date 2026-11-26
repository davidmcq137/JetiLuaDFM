// LiFe.swift: the Swift port of LiFe.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Functions/LiFe.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// LiFe.lua: a LiFe cell's voltage from its state of charge (%) and
/// back, interpolating in the table (full first), for formulas:
/// LiFeV(SOC), LiFeS(Volt).
nonisolated enum LiFe {
    static let table: [(s: Double, v: Double)] = [
        (s: 100.00, v: 3.59),
        (s: 95.71, v: 3.32),
        (s: 91.47, v: 3.316),
        (s: 87.09, v: 3.313),
        (s: 82.85, v: 3.306),
        (s: 78.54, v: 3.304),
        (s: 74.18, v: 3.29),
        (s: 69.92, v: 3.28),
        (s: 65.61, v: 3.278),
        (s: 61.31, v: 3.276),
        (s: 57.05, v: 3.274),
        (s: 52.74, v: 3.272),
        (s: 48.46, v: 3.269),
        (s: 44.14, v: 3.266),
        (s: 39.83, v: 3.263),
        (s: 35.55, v: 3.25),
        (s: 31.24, v: 3.24),
        (s: 26.87, v: 3.23),
        (s: 22.59, v: 3.22),
        (s: 18.24, v: 3.20),
        (s: 13.88, v: 3.19),
        (s: 9.63, v: 3.17),
        (s: 5.35, v: 3.12),
        (s: 1.01, v: 2.90),
    ]

    /// LiFeV(SOC): volts per cell at a state of charge (%).
    static func LiFeV(_ soc: Double) -> Double? {
        let t = table
        if soc >= t[0].s { return t[0].v }
        if soc <= t[t.count - 1].s { return t[t.count - 1].v }
        for i in 0..<(t.count - 1) where soc >= t[i + 1].s && soc <= t[i].s {
            let ds = (soc - t[i + 1].s) / (t[i].s - t[i + 1].s)
            return t[i + 1].v + ds * (t[i].v - t[i + 1].v)
        }
        return nil
    }

    /// LiFeS(Volt): state of charge (%) at a cell voltage.
    static func LiFeS(_ volt: Double) -> Double? {
        let t = table
        if volt >= t[0].v { return t[0].s }
        if volt <= t[t.count - 1].v { return t[t.count - 1].s }
        for i in 0..<(t.count - 1) where volt >= t[i + 1].v && volt <= t[i].v {
            let dv = (volt - t[i + 1].v) / (t[i].v - t[i + 1].v)
            return t[i + 1].s + dv * (t[i].s - t[i + 1].s)
        }
        return nil
    }
}
