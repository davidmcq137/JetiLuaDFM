// VSpeakKingTech.swift: the Swift port of VSpeakKingTech.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Extensions/VSpeakKingTech.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// VSpeakKingTech.lua: an ECU's status code as text, for a text box. (Sound
/// file names some of these tables have are for spoken alerts; the iOS
/// app has no audio.)
nonisolated enum VSpeakKingTech {
    static let messages: [Int: String] = [
        -20: "Error",
        -19: "Unknown",
        -13: "CAB Lost",
        -12: "Flame Out",
        -11: "Temp High",
        -10: "Speed Low",
        -9: "Failsafe",
        -8: "Rx Pw Fail",
        -7: "Overload",
        -6: "Low Batt",
        -5: "Start Bad",
        -4: "Weak Gas",
        -3: "Timeout",
        -2: "Ign Fail",
        -1: "Glow Bad",
        0: "Trim Low",
        1: "User Off",
        2: "Stop",
        3: "Cooling",
        4: "Ready",
        5: "Gd Ready",
        6: "Glow Test",
        7: "Stick Lo",
        8: "Prime Vap",
        9: "Burner On",
        10: "Start On",
        11: "Ignition",
        12: "Stage 1",
        13: "Stage 2",
        14: "Stage 3",
        20: "Running",
        22: "Re-Start",
    ]

    /// M.text(): the message for a status code, as the text box's text;
    /// nil where DFM-InsP would show the box's own text.
    static func text(_ v: Double?) -> [String]? {
        // Otherwise the Lua returns a plain string, which DFM-InsP ignores.
        guard let v, v == v.rounded(), abs(v) < 1e15, let m = messages[Int(v)] else { return nil }
        return [m]
    }
}
