// CTUKingTechG2G3.swift: the Swift port of CTUKingTechG2G3.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Extensions/CTUKingTechG2G3.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// CTUKingTechG2G3.lua: an ECU's status code as text, for a text box. (Sound
/// file names some of these tables have are for spoken alerts; the iOS
/// app has no audio.)
nonisolated enum CTUKingTechG2G3 {
    static let messages: [Int: String] = [
        1536: "Trim Low",
        1537: "Ready",
        1538: "StickLo!",
        1539: "GlowTest",
        1540: "Start On",
        1541: "Ignition",
        1542: "Preheat",
        1543: "FuelRamp",
        1544: "Running",
        1545: "Stop",
        1546: "Cooling",
        1547: "GlowBad",
        1548: "StartBad",
        1549: "Low RPM",
        1550: "HighTemp",
        1551: "FlameOut",
        1552: "PrimeVap",
        1553: "Stage1",
        1554: "Stage2",
        1555: "Stage3",
        1556: "BurnerOn",
        1557: "Low Batt",
        1558: "SpeedLow",
        1559: "Restart",
        1560: "Glow Bad",
    ]

    /// M.text(): the message for a status code, as the text box's text;
    /// nil where DFM-InsP would show the box's own text.
    static func text(_ v: Double?) -> [String]? {
        // Otherwise the Lua returns a plain string, which DFM-InsP ignores.
        guard let v, v == v.rounded(), abs(v) < 1e15, let m = messages[Int(v)] else { return nil }
        return [m]
    }
}
