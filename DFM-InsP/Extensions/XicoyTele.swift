// XicoyTele.swift: the Swift port of XicoyTele.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Extensions/XicoyTele.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// XicoyTele.lua: an ECU's status code as text, for a text box. (Sound
/// file names some of these tables have are for spoken alerts; the iOS
/// app has no audio.)
nonisolated enum XicoyTele {
    static let messages: [Int: String] = [
        0: "High Temp",
        1: "Trim Low",
        2: "Set Idle!",
        3: "Ready",
        4: "Ignition",
        5: "Fuelramp",
        6: "Glow Test",
        7: "Running",
        8: "Stop",
        9: "Flameout",
        10: "SpeedLow",
        11: "Cooling",
        12: "Ignitor Bad",
        13: "StarterFail",
        14: "AccelFail",
        15: "Start On",
        16: "UserOff",
        17: "Failsafe",
        18: "Low RPM",
        19: "Reset ",
        20: "RXPwFail",
        21: "Preheat",
        22: "Battery Low",
        23: "Time Out",
        24: "Overload",
        25: "Ignition Fail",
        26: "Burner On",
        27: "Starting",
        28: "SwitchOv",
        29: "Cal.Pump",
        30: "PumpLimit",
        31: "NoEngine",
        32: "PwrBoost",
        33: "Run-Idle",
        34: "Run-Max ",
        35: "Restart ",
        36: "Error   ",
        255: "ECU Offline",
    ]

    /// M.text(): the message for a status code, as the text box's text;
    /// nil where DFM-InsP would show the box's own text.
    static func text(_ v: Double?) -> [String]? {
        // Otherwise the Lua returns a plain string, which DFM-InsP ignores.
        guard let v, v == v.rounded(), abs(v) < 1e15, let m = messages[Int(v)] else { return nil }
        return [m]
    }
}
