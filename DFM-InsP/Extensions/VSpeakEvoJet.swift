// VSpeakEvoJet.swift: the Swift port of VSpeakEvoJet.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Extensions/VSpeakEvoJet.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// VSpeakEvoJet.lua: an ECU's status code as text, for a text box. (Sound
/// file names some of these tables have are for spoken alerts; the iOS
/// app has no audio.)
nonisolated enum VSpeakEvoJet {
    static let messages: [Int: String] = [
        -30: "TH:error",
        -20: "TH:off",
        -10: "TH:cool",
        -1: "TH:lock",
        0: "TH:stop",
        10: "TH:run",
        20: "TH:rel",
        25: "TH:glow",
        30: "TH:spin",
        40: "TH:fire",
        45: "TH:ignt",
        50: "TH:heat",
        60: "TH:acce",
        65: "TH:cal.",
        70: "TH:idle",
    ]

    /// M.text(): the message for a status code, as the text box's text;
    /// nil where DFM-InsP would show the box's own text.
    static func text(_ v: Double?) -> [String]? {
        // Otherwise the Lua returns a plain string, which DFM-InsP ignores.
        guard let v, v == v.rounded(), abs(v) < 1e15, let m = messages[Int(v)] else { return nil }
        return [m]
    }
}
