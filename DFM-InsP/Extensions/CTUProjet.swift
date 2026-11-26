// CTUProjet.swift: the Swift port of CTUProjet.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Extensions/CTUProjet.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// CTUProjet.lua: an ECU's status code as text, for a text box. (Sound
/// file names some of these tables have are for spoken alerts; the iOS
/// app has no audio.)
nonisolated enum CTUProjet {
    static let messages: [Int: String] = [
        0: "Off",
        1: "Standby",
        2: "Auto",
        5: "Ignition",
        7: "Ramp Up",
        8: "---",
        9: "Slow Down",
        10: "Cool Down",
        11: "Calibrate",
        12: "Cal. Idle",
        13: "Gi Idle",
        14: "---",
        15: "Burner On",
        16: "Auto HHC",
        18: "Wait Acc",
        23: "Preheat",
        25: "Burn Out",
        26: "Steady",
    ]

    /// M.text(): the message for a status code, as the text box's text;
    /// nil where DFM-InsP would show the box's own text.
    static func text(_ v: Double?) -> [String]? {
        // Otherwise the Lua returns a plain string, which DFM-InsP ignores.
        guard let v, v == v.rounded(), abs(v) < 1e15, let m = messages[Int(v)] else { return nil }
        return [m]
    }
}
