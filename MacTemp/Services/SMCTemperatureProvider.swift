import Foundation
import IOKit

protocol TemperatureProviding {
    func readTemperatures() throws -> [TemperatureReading]
}

enum SensorReaderError: LocalizedError {
    case controllerUnavailable
    case connectionFailed(kern_return_t)
    case noTemperaturesFound
    case readFailed(String)

    var errorDescription: String? {
        switch self {
        case .controllerUnavailable:
            "Mac sensor controller not found."
        case .connectionFailed:
            "MacTemp cannot open the sensor controller."
        case .noTemperaturesFound:
            "This Mac did not report any supported temperature sensors."
        case let .readFailed(key):
            "Could not read sensor \(key)."
        }
    }
}

final class SMCTemperatureProvider: TemperatureProviding {
    private var connection: io_connect_t = 0

    init() {
        connection = Self.openSMCConnection()
    }

    private static func openSMCConnection() -> io_connect_t {
        let service = Self.sensorService()

        guard service != 0 else {
            return 0
        }

        defer { IOObjectRelease(service) }

        var connection: io_connect_t = 0
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard result == KERN_SUCCESS else {
            return 0
        }

        return connection
    }

    private static func sensorService() -> io_service_t {
        for serviceClass in ["AppleSMCKeysEndpoint", "AppleSMC"] {
            let matching = IOServiceMatching(serviceClass)
            let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
            if service != 0 {
                return service
            }
        }
        return 0
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    func readTemperatures() throws -> [TemperatureReading] {
        let hidReadings = readHIDTemperatures()
        if !hidReadings.isEmpty {
            return hidReadings
        }

        guard connection != 0 else {
            throw SensorReaderError.controllerUnavailable
        }

        let readings = TemperatureComponent.allCases.compactMap { component -> TemperatureReading? in
            for key in component.preferredKeys {
                if let temperature = try? readTemperature(for: key) {
                    return TemperatureReading(component: component, celsius: temperature, sensorKey: key)
                }
            }
            return nil
        }

        guard !readings.isEmpty else {
            throw SensorReaderError.noTemperaturesFound
        }

        return readings
    }

    private func readHIDTemperatures() -> [TemperatureReading] {
        let sensors = HIDTemperatureReader.readSensors().compactMap { sensor -> (component: TemperatureComponent, value: Double, name: String)? in
            guard
                let name = sensor["name"] as? String,
                let number = sensor["temperature"] as? NSNumber
            else {
                return nil
            }

            return (component: component(forHIDSensorNamed: name), value: number.doubleValue, name: name)
        }

        let grouped = Dictionary(grouping: sensors, by: \.component)
        return TemperatureComponent.allCases.compactMap { component in
            guard let values = grouped[component], !values.isEmpty else { return nil }
            let hottest = values.max(by: { $0.value < $1.value })!
            return TemperatureReading(component: component, celsius: hottest.value, sensorKey: hottest.name)
        }
    }

    private func component(forHIDSensorNamed name: String) -> TemperatureComponent {
        let lowercasedName = name.lowercased()

        if lowercasedName.contains("gpu") || lowercasedName.contains("graphics") {
            return .gpu
        }
        if lowercasedName.contains("memory") || lowercasedName.contains("dram") {
            return .memory
        }
        if lowercasedName.contains("battery") {
            return .battery
        }
        if lowercasedName.contains("ssd") || lowercasedName.contains("nand") || lowercasedName.contains("storage") {
            return .storage
        }
        if lowercasedName.contains("ambient") || lowercasedName.contains("air") {
            return .ambient
        }
        return .cpu
    }

    private func readTemperature(for key: String) throws -> Double {
        let info = try readKeyInfo(for: key)
        guard info.dataSize > 0, info.dataSize <= 32 else {
            throw SensorReaderError.readFailed(key)
        }

        let bytes = try readBytes(for: key, keyInfo: info)
        guard let temperature = decodeTemperature(bytes: bytes, type: info.dataType), (-30...150).contains(temperature) else {
            throw SensorReaderError.readFailed(key)
        }

        return temperature
    }

    private func readKeyInfo(for key: String) throws -> SMCKeyInfoData {
        var input = SMCParamStruct()
        input.key = fourCharCode(key)
        input.data8 = SMCCommand.getKeyInfo.rawValue

        let output = try call(input)
        return output.keyInfo
    }

    private func readBytes(for key: String, keyInfo: SMCKeyInfoData) throws -> [UInt8] {
        var input = SMCParamStruct()
        input.key = fourCharCode(key)
        input.keyInfo = keyInfo
        input.data8 = SMCCommand.readBytes.rawValue

        let output = try call(input)
        return withUnsafeBytes(of: output.bytes) { bytes in
            Array(bytes.prefix(Int(keyInfo.dataSize)))
        }
    }

    private func call(_ input: SMCParamStruct) throws -> SMCParamStruct {
        var mutableInput = input
        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.size

        let result = withUnsafePointer(to: &mutableInput) { inputPointer in
            withUnsafeMutablePointer(to: &output) { outputPointer in
                IOConnectCallStructMethod(
                    connection,
                    SMCSelector.handleYPCEvent.rawValue,
                    inputPointer,
                    MemoryLayout<SMCParamStruct>.size,
                    outputPointer,
                    &outputSize
                )
            }
        }

        guard result == KERN_SUCCESS else {
            throw SensorReaderError.readFailed("SMC")
        }

        return output
    }

    private func decodeTemperature(bytes: [UInt8], type: UInt32) -> Double? {
        let typeName = keyString(type)
        guard bytes.count >= 2 else { return nil }

        switch typeName {
        case "sp78":
            let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
            return Double(raw) / 256
        case "fp88":
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(raw) / 256
        case "fpe2":
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(raw) / 4
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let raw = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
            return Double(Float(bitPattern: raw))
        default:
            return nil
        }
    }

    private func fourCharCode(_ text: String) -> UInt32 {
        text.utf8.prefix(4).reduce(0) { partial, byte in
            (partial << 8) | UInt32(byte)
        }
    }

    private func keyString(_ code: UInt32) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }
}

private enum SMCSelector: UInt32 {
    case handleYPCEvent = 2
}

private enum SMCCommand: UInt8 {
    case readBytes = 5
    case getKeyInfo = 9
}

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPowerLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private struct SMCParamStruct {
    var key: UInt32 = 0
    var version = SMCVersion()
    var powerLimitData = SMCPowerLimitData()
    var keyInfo = SMCKeyInfoData()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}
