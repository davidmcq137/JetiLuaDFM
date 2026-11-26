// EnJet.swift: the Swift port of EnJet.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Extensions/EnJet.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// EnJet.lua: an ECU's status code as text, for a text box. (Sound
/// file names some of these tables have are for spoken alerts; the iOS
/// app has no audio.)
nonisolated enum EnJet {
    static let messages: [Int: String] = [
        0: "Downtime",
        1: "Starting",
        2: "Running",
        3: "Cold machine",
        4: "Flameout restart",
        7: "Component test",
        8: "Remote control calibration",
        9: "Flameout restart",
        11: "Engine ready",
        33: "Startup stage 1",
        34: "Startup stage 2",
        35: "Startup stage 3",
        36: "Startup stage 4",
        37: "Startup stage 5",
        38: "Startup stage 6",
    ]

    /// M.text(): the message for a status code, as the text box's text;
    /// nil where DFM-InsP would show the box's own text.
    static func text(_ v: Double?) -> [String]? {
        // Otherwise the Lua returns a plain string, which DFM-InsP ignores.
        guard let v, v == v.rounded(), abs(v) < 1e15, let m = messages[Int(v)] else { return nil }
        return [m]
    }
}
