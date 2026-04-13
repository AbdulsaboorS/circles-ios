import SwiftUI

enum CircleColorDeriver {
    private static func nameHash(_ name: String) -> Int {
        abs(name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
    }

    static func gradient(for name: String) -> [Color] {
        let palettes: [[Color]] = [
            [Color(hex: "1A2E1E"), Color(hex: "243828")],
            [Color(hex: "1E2A30"), Color(hex: "1A3040")],
            [Color(hex: "2A1E1E"), Color(hex: "3A2828")],
            [Color(hex: "1E2420"), Color(hex: "2A3830")],
            [Color(hex: "2A2818"), Color(hex: "3A3620")],
            [Color(hex: "201E2A"), Color(hex: "2C2838")]
        ]
        return palettes[nameHash(name) % palettes.count]
    }

    static func accent(for name: String) -> Color {
        let accents: [Color] = [
            Color(hex: "4A9E6B"),
            Color(hex: "5B8EC9"),
            Color(hex: "C96B5B"),
            Color(hex: "8B6BBF"),
            Color(hex: "D4A240"),
            Color(hex: "5BBFB0")
        ]
        return accents[nameHash(name) % accents.count]
    }
}
