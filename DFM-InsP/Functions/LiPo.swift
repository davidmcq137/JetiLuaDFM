// LiPo.swift: the Swift port of LiPo.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Functions/LiPo.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// LiPo.lua: a LiPo cell's voltage from its state of charge (%) and
/// back, interpolating in the table (full first), for formulas:
/// LiPoV(SOC), LiPoS(Volt).
nonisolated enum LiPo {
    static let table: [(s: Double, v: Double)] = [
        (s: 100, v: 4.2),
        (s: 95, v: 4.15),
        (s: 90, v: 4.11),
        (s: 85, v: 4.08),
        (s: 80, v: 4.02),
        (s: 75, v: 3.98),
        (s: 70, v: 3.95),
        (s: 65, v: 3.91),
        (s: 60, v: 3.87),
        (s: 55, v: 3.85),
        (s: 50, v: 3.84),
        (s: 45, v: 3.82),
        (s: 40, v: 3.80),
        (s: 35, v: 3.79),
        (s: 30, v: 3.77),
        (s: 25, v: 3.75),
        (s: 20, v: 3.73),
        (s: 15, v: 3.71),
        (s: 10, v: 3.69),
        (s: 5, v: 3.61),
        (s: 0, v: 3.27),
    ]

    /// LiPoV(SOC): volts per cell at a state of charge (%).
    static func LiPoV(_ soc: Double) -> Double? {
        let t = table
        if soc >= t[0].s { return t[0].v }
        if soc <= t[t.count - 1].s { return t[t.count - 1].v }
        for i in 0..<(t.count - 1) where soc >= t[i + 1].s && soc <= t[i].s {
            let ds = (soc - t[i + 1].s) / (t[i].s - t[i + 1].s)
            return t[i + 1].v + ds * (t[i].v - t[i + 1].v)
        }
        return nil
    }

    /// LiPoS(Volt): state of charge (%) at a cell voltage.
    static func LiPoS(_ volt: Double) -> Double? {
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
