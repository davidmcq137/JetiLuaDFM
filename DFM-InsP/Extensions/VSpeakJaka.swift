// VSpeakJaka.swift: the Swift port of VSpeakJaka.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Extensions/VSpeakJaka.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// VSpeakJaka.lua: an ECU's status code as text, for a text box. (Sound
/// file names some of these tables have are for spoken alerts; the iOS
/// app has no audio.)
nonisolated enum VSpeakJaka {
    static let messages: [Int: String] = [
        -30: "Error -30",
        -20: "TH:off",
        -10: "TH:cool",
        -1: "TH:lock",
        0: "TH:stop",
        10: "TH:run",
        20: "TH:rel",
        30: "TH:spin",
        40: "TH:fire",
        50: "TH:heat",
        60: "TH:acce",
        70: "TH:idle",
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
