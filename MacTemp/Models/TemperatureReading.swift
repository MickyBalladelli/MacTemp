import Foundation
import SwiftUI

enum TemperatureComponent: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case gpu = "GPU"
    case memory = "Memory"
    case battery = "Battery"
    case storage = "Storage"
    case ambient = "Ambient"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cpu: "cpu"
        case .gpu: "rectangle.3.group"
        case .memory: "memorychip"
        case .battery: "battery.75percent"
        case .storage: "internaldrive"
        case .ambient: "thermometer.medium"
        }
    }

    var preferredKeys: [String] {
        switch self {
        case .cpu:
            ["Tp0T", "TC0P", "TC0D", "TC0F", "Tp01", "Tp09"]
        case .gpu:
            ["Tp05", "TG0D", "TG0P", "TG1D", "TG1P", "Tp06"]
        case .memory:
            ["Tm0P", "TM0P", "TM0S", "TM0C", "Tm02", "Tm06"]
        case .battery:
            ["TB0T", "TB1T", "TB2T"]
        case .storage:
            ["TH0P", "TH0x", "TH1P"]
        case .ambient:
            ["TA0P", "TA0S", "TA0V"]
        }
    }
}

struct TemperatureReading: Identifiable, Hashable {
    let component: TemperatureComponent
    let celsius: Double
    let sensorKey: String

    var id: TemperatureComponent { component }

    var fahrenheit: Double {
        celsius * 9 / 5 + 32
    }

    var valueText: String {
        "\(Int(celsius.rounded()))°"
    }

    var detailedValueText: String {
        "\(Int(celsius.rounded()))°C"
    }

    var condition: TemperatureCondition {
        switch celsius {
        case ..<55: .cool
        case ..<75: .warm
        case ..<90: .hot
        default: .critical
        }
    }
}

enum TemperatureCondition {
    case cool
    case warm
    case hot
    case critical

    var label: String {
        switch self {
        case .cool: "Cool"
        case .warm: "Warm"
        case .hot, .critical: "Hot"
        }
    }

    var color: Color {
        switch self {
        case .cool: Color(red: 0.24, green: 0.84, blue: 0.72)
        case .warm: Color(red: 1, green: 0.74, blue: 0.25)
        case .hot: Color(red: 1, green: 0.37, blue: 0.28)
        case .critical: Color(red: 1, green: 0.22, blue: 0.34)
        }
    }
}
