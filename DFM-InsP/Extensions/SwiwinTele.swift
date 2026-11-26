// SwiwinTele.swift: the Swift port of SwiwinTele.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Extensions/SwiwinTele.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// SwiwinTele.lua: an ECU's status code as text, for a text box. (Sound
/// file names some of these tables have are for spoken alerts; the iOS
/// app has no audio.)
nonisolated enum SwiwinTele {
    static let messages: [Int: String] = [
        0: "Stop",
        1: "Ready",
        3: "Ignition",
        4: "Preheat",
        5: "Fuel Ramp",
        11: "Running",
        12: "Cooling",
        13: "Restart",
    ]

    /// M.text(): the message for a status code, as the text box's text;
    /// nil where DFM-InsP would show the box's own text.
    static func text(_ v: Double?) -> [String]? {
        // Otherwise the Lua returns a plain string, which DFM-InsP ignores.
        guard let v, v == v.rounded(), abs(v) < 1e15, let m = messages[Int(v)] else { return nil }
        return [m]
    }
}
