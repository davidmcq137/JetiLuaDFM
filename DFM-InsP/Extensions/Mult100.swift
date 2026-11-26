// Mult100.swift: the Swift port of Mult100.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Extensions/Mult100.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// Mult100.lua: the value multiplied by 100 (no value counts as 0).
nonisolated enum Mult100 {
    static func value(_ v: Double?) -> Double { (v ?? 0) * 100 }
}
