// VSpeakJetCat.swift: the Swift port of VSpeakJetCat.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Extensions/VSpeakJetCat.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// VSpeakJetCat.lua: an ECU's status code as text, for a text box. (Sound
/// file names some of these tables have are for spoken alerts; the iOS
/// app has no audio.)
nonisolated enum VSpeakJetCat {
    static let messages: [Int: String] = [
        -3: "Manual Off",
        -2: "Auto Off",
        -1: "Shutdown RC",
        0: "Off",
        1: "Slow Down",
        2: "AutoOff",
        3: "Wait for RPM",
        4: "PreHeat1",
        5: "PreHeat2",
        6: "Ignite",
        7: "Accel Delay",
        8: "MainFStrt",
        9: "KeroFullOn",
        10: "Accelerate",
        11: "Stabilize",
        12: "Learn LO",
        13: "Run",
        14: "SpeedReg",
        15: "TwoShaftReg",
    ]

    /// M.text(): the message for a status code, as the text box's text;
    /// nil where DFM-InsP would show the box's own text.
    static func text(_ v: Double?) -> [String]? {
        guard let v else { return ["Invalid:nil"] }
        if v == v.rounded(), abs(v) < 1e15, let m = messages[Int(v)] { return [m] }
        if v < -3 { return ["Error: " + luaString(v)] }
        return ["Status: " + luaString(v)]
    }

    /// The value as the Lua's tostring() writes it (whole numbers without
    /// decimals).
    static func luaString(_ v: Double) -> String {
        v == v.rounded() && abs(v) < 1e15 ? String(Int(v)) : String(format: "%.14g", v)
    }
}
