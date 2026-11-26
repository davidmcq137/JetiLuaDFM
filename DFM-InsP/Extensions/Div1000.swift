// Div1000.swift: the Swift port of Div1000.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Extensions/Div1000.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// Div1000.lua: the value divided by 1000 (no value counts as 0).
nonisolated enum Div1000 {
    static func value(_ v: Double?) -> Double { (v ?? 0) / 1000 }
}
