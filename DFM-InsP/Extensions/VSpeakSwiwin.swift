// VSpeakSwiwin.swift: the Swift port of VSpeakSwiwin.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Extensions/VSpeakSwiwin.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// VSpeakSwiwin.lua: an ECU's status code as text, for a text box. (Sound
/// file names some of these tables have are for spoken alerts; the iOS
/// app has no audio.)
nonisolated enum VSpeakSwiwin {
    static let messages: [Int: String] = [
        0: "Stop",
        1: "Cooling",
        5: "TestGlowPlug",
        6: "TestFuelValve",
        7: "TestGasValve",
        8: "TestPump",
        9: "TestStarter",
        10: "Ready",
        11: "Ignition",
        12: "Preheat",
        13: "Fuelramp",
        20: "Running",
        21: "Restart",
    ]

    /// M.text(): the message for a status code, as the text box's text;
    /// nil where DFM-InsP would show the box's own text.
    static func text(_ v: Double?) -> [String]? {
        guard let v else { return ["Invalid:nil"] }
        if v == v.rounded(), abs(v) < 1e15, let m = messages[Int(v)] { return [m] }
        if v < 0 { return ["Error: " + luaString(v)] }
        return ["Status: " + luaString(v)]
    }

    /// The value as the Lua's tostring() writes it (whole numbers without
    /// decimals).
    static func luaString(_ v: Double) -> String {
        v == v.rounded() && abs(v) < 1e15 ? String(Int(v)) : String(format: "%.14g", v)
    }
}
