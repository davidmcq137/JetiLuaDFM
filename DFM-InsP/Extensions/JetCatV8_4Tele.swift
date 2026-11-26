// JetCatV8_4Tele.swift: the Swift port of JetCatV8_4Tele.lua, for the iOS app
// (dfmBleApp), which can't load Lua extensions from the repository.
//
// Master copy: JetiLuaDFM, DFM-InsP/Extensions/JetCatV8_4Tele.swift. The iOS app
// keeps a copy; change this one, then sync the copy with dfmBleApp's
// tools/sync-insp-swift.sh. Self-contained: Foundation only.

import Foundation

/// JetCatV8_4Tele.lua: an ECU's status code as text, for a text box. (Sound
/// file names some of these tables have are for spoken alerts; the iOS
/// app has no audio.)
nonisolated enum JetCatV8_4Tele {
    static let messages: [Int: String] = [
        -36: "Safety Pin Signal",
        -35: "Rotor Blocked",
        -34: "No RC Pulse",
        -33: "No CAN Bus",
        -32: "ECU reboot, new engine",
        -31: "Clutch Fail",
        -30: "LowRPM shutdown",
        -29: "LowRPM Shutdown",
        -28: "OutOfFuel shutdown",
        -27: "FuelPump comm error",
        -26: "WrongFuelPump",
        -25: "NoFuelPump found",
        -24: "Over Current",
        -23: "No oil",
        -22: "2nd engine no comms",
        -21: "2nd engine diff high",
        -20: "2nd engine fail",
        -19: "Prop fail",
        -18: "Fuel fail",
        -17: "Temp Sensor fail",
        -16: "Power Fail",
        -15: "Manual Off by GSU",
        -14: "Failsafe Off",
        -13: "WatchDog Timer",
        -12: "GlowPlug defective",
        -11: "Hi Temp Off",
        -10: "LowTemp Off",
        -9: "Auto Off",
        -8: "Low Battery",
        -7: "LowRPM Off",
        -6: "Over RPM",
        -5: "Accel. TooSlow",
        -4: "Accel. TimeOut",
        -3: "Ignition TimeOut",
        -2: "Over Temp",
        -1: "Shutdown by RC",
        0: "Off",
        1: "Wait for RPM",
        2: "Ignite",
        3: "Accelerate",
        4: "Stabilise",
        5: "",
        6: "LearnLO",
        7: "",
        8: "Slow Down",
        9: "",
        10: "Auto Off",
        11: "Run (reg.)",
        12: "Acceleration delay",
        13: "Speed Reg",
        14: "TwoShaftReg",
        15: "PreHeat 1",
        16: "PreHeat 2",
        19: "Keros FullOn",
    ]

    /// M.text(): the message for a status code, as the text box's text;
    /// nil where DFM-InsP would show the box's own text.
    static func text(_ v: Double?) -> [String]? {
        guard let v else { return ["Invalid:nil"] }
        if v == v.rounded(), abs(v) < 1e15, let m = messages[Int(v)] { return [m] }
        if v < -3 { return ["Error: " + luaString(v)] }
        return ["Status: " + luaString(v)]
    }

    /// The value as the Lua's tostring() writes it (whole numbers without
    /// decimals).
    static func luaString(_ v: Double) -> String {
        v == v.rounded() && abs(v) < 1e15 ? String(Int(v)) : String(format: "%.14g", v)
    }
}
