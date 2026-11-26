// VSpeakAMT.swift: the Swift port of VSpeakAMT.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Extensions/VSpeakAMT.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// VSpeakAMT.lua: an ECU's status code as text, for a text box. (Sound
/// file names some of these tables have are for spoken alerts; the iOS
/// app has no audio.)
nonisolated enum VSpeakAMT {
    static let messages: [Int: String] = [
        -20: "Error",
        -8: "Supply ASS low",
        -7: "Supply low error",
        -6: "RPM high error",
        -5: "EGT error",
        -4: "Throttle fail",
        -3: "Switch fail",
        -2: "RPM low error",
        -1: "No serial input",
        0: "No start clearance",
        1: "Start clearance",
        2: "Starting",
        3: "Started up",
        4: "Calibrated",
        5: "Auto stop",
        6: "Running",
        7: "Max. RPM",
    ]

    /// M.text(): the message for a status code, as the text box's text;
    /// nil where DFM-InsP would show the box's own text.
    static func text(_ v: Double?) -> [String]? {
        guard let v else { return ["Invalid: nil"] }
        if v == v.rounded(), abs(v) < 1e15, let m = messages[Int(v)] { return [m] }
        return ["Status: " + luaString(v)]
    }

    /// The value as the Lua's tostring() writes it (whole numbers without
    /// decimals).
    static func luaString(_ v: Double) -> String {
        v == v.rounded() && abs(v) < 1e15 ? String(Int(v)) : String(format: "%.14g", v)
    }
}
