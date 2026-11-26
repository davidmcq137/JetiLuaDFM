// gratio.swift: the Swift port of gratio.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Functions/gratio.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// gratio.lua: gratio(airspeed, vario), the glide ratio, for formulas.
nonisolated enum Gratio {
    static let maxRatio = 1000.0

    /// 0 if either is missing. (The Lua has `speed` for `airspeed` in the
    /// past-maxRatio branch, an error on the TX; this uses airspeed.)
    static func gratio(_ airspeed: Double?, _ vario: Double?) -> Double {
        guard let airspeed, let vario else { return 0 }
        if abs(airspeed / vario) < maxRatio {
            let arg = airspeed * airspeed - vario * vario
            return arg > 0 ? arg.squareRoot() / vario : airspeed / vario
        }
        return airspeed / vario >= 0 ? maxRatio : -maxRatio
    }
}
