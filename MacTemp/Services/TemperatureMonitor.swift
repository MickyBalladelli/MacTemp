import Foundation

@MainActor
final class TemperatureMonitor: ObservableObject {
    @Published private(set) var readings: [TemperatureReading] = []
    @Published private(set) var history: [TemperatureComponent: [Double]] = [:]
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var errorMessage: String?

    private let provider = SMCTemperatureProvider()
    private var refreshTimer: Timer?

    func start() {
        guard refreshTimer == nil else { return }
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh() {
        do {
            let newReadings = try provider.readTemperatures()
            readings = newReadings
            errorMessage = nil
            lastUpdated = .now

            for reading in newReadings {
                var values = history[reading.component, default: []]
                values.append(reading.celsius)
                history[reading.component] = Array(values.suffix(45))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
