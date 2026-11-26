// VSpeakProjet.swift: the Swift port of VSpeakProjet.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Extensions/VSpeakProjet.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// VSpeakProjet.lua: an ECU's status code as text, for a text box. (Sound
/// file names some of these tables have are for spoken alerts; the iOS
/// app has no audio.)
nonisolated enum VSpeakProjet {
    static let messages: [Int: String] = [
        -30: "Dev. Delay",
        -10: "Emergency",
        0: "Off",
        10: "Cool Down",
        20: "Slow Down",
        30: "Standby",
        31: "Prop Ignit",
        32: "Prop Heat",
        33: "Pump Start",
        34: "Burner On",
        35: "Fuel Ignit",
        36: "Fuel Heat",
        37: "Ramp Delay",
        38: "Ramp Up",
        40: "Steady",
        41: "Cal Idle",
        42: "Calibrate",
        43: "Wait Acc",
        44: "Go Idle",
        50: "Auto",
        51: "Auto HC",
    ]

    /// M.text(): the message for a status code, as the text box's text;
    /// nil where DFM-InsP would show the box's own text.
    static func text(_ v: Double?) -> [String]? {
        // Otherwise the Lua returns a plain string, which DFM-InsP ignores.
        guard let v, v == v.rounded(), abs(v) < 1e15, let m = messages[Int(v)] else { return nil }
        return [m]
    }
}
