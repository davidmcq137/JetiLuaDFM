// Switch2Seq.swift: the Swift port of Switch2Seq.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Extensions/Switch2Seq.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// Switch2Seq.lua: a 3-position switch (-1, 0, 1) as a text box index:
/// 1, 2, 3 (no value counts as 0).
nonisolated enum Switch2Seq {
    static func value(_ v: Double?) -> Double {
        let v = v ?? 0
        return v > 0.5 ? 3 : v < -0.5 ? 1 : 2
    }
}
