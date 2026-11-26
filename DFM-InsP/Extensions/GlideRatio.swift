// GlideRatio.swift: the Swift port of GlideRatio.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Extensions/GlideRatio.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// GlideRatio.lua: the glide ratio from the gauge's value (airspeed) and
/// the pilot's Lua variable named "vario" (on the TX, from ptr.variables).
nonisolated enum GlideRatio {
    static let maxRatio = 1000.0

    /// M.val(): -9000 with no airspeed, -9001 with no vario.
    static func val(_ speed: Double?, vario: Double?) -> Double {
        guard let speed else { return -9000 }
        guard let vario else { return -9001 }
        if abs(speed / vario) < maxRatio {
            let arg = speed * speed - vario * vario
            return arg > 0 ? arg.squareRoot() / vario : speed / vario
        }
        return speed / vario >= 0 ? maxRatio : -maxRatio
    }
}
