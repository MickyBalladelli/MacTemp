import SwiftUI

struct ContentView: View {
    @ObservedObject var monitor: TemperatureMonitor

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.035, green: 0.055, blue: 0.10), Color(red: 0.075, green: 0.055, blue: 0.13)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.27, green: 0.25, blue: 0.88).opacity(0.20))
                .frame(width: 460)
                .blur(radius: 90)
                .offset(x: 330, y: -250)

            ScrollView {
                VStack(spacing: 22) {
                    header

                    if monitor.readings.isEmpty {
                        EmptyState(message: monitor.errorMessage)
                    } else {
                        dashboard
                    }
                }
                .padding(28)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 9) {
                    Image(systemName: "thermometer.medium")
                        .foregroundStyle(Color(red: 0.35, green: 0.85, blue: 1))
                    Text("MAC TEMP")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .tracking(1.8)
                }

                Text("Your Mac, right now")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Label("LIVE", systemImage: "circle.fill")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.28, green: 0.88, blue: 0.65))
                Text(lastUpdatedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: monitor.refresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .background(.white.opacity(0.10), in: Circle())
            .accessibilityLabel("Refresh temperatures")
        }
    }

    private var dashboard: some View {
        VStack(spacing: 16) {
            if let cpu = monitor.readings.first(where: { $0.component == .cpu }) {
                HeroTemperatureCard(reading: cpu, values: monitor.history[.cpu, default: []])
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(monitor.readings.filter { $0.component != .cpu }) { reading in
                    TemperatureCard(
                        reading: reading,
                        values: monitor.history[reading.component, default: []]
                    )
                }
            }

            if let errorMessage = monitor.errorMessage {
                HStack(spacing: 9) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(errorMessage)
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
            }
        }
    }

    private var lastUpdatedText: String {
        guard let date = monitor.lastUpdated else { return "Checking sensors" }
        return "Updated \(date.formatted(date: .omitted, time: .standard))"
    }
}

private struct HeroTemperatureCard: View {
    let reading: TemperatureReading
    let values: [Double]

    var body: some View {
        HStack(spacing: 30) {
            VStack(alignment: .leading, spacing: 14) {
                Label(reading.component.rawValue.uppercased(), systemImage: reading.component.icon)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(reading.valueText)
                        .font(.system(size: 78, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("C")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 7) {
                    Circle()
                        .fill(reading.condition.color)
                        .frame(width: 7, height: 7)
                    Text(reading.condition.label)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(reading.condition.color)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 14) {
                Sparkline(values: values, color: reading.condition.color, lineWidth: 4)
                    .frame(width: 250, height: 105)

                HStack(spacing: 18) {
                    Stat(label: "SENSOR", value: reading.sensorKey)
                    Stat(label: "NOW", value: "\(Int(reading.fahrenheit.rounded()))°F")
                }
            }
        }
        .padding(28)
        .background(
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.18, blue: 0.30), Color(red: 0.10, green: 0.11, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(reading.condition.color.opacity(0.16))
                .frame(width: 180, height: 180)
                .blur(radius: 30)
                .offset(x: 40, y: -65)
                .allowsHitTesting(false)
        }
    }
}

private struct TemperatureCard: View {
    let reading: TemperatureReading
    let values: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Image(systemName: reading.component.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(reading.condition.color)
                    .frame(width: 28, height: 28)
                    .background(reading.condition.color.opacity(0.14), in: Circle())

                Spacer()

                Text(reading.condition.label.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(reading.condition.color)
            }

            Text(reading.component.rawValue)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(reading.valueText)
                    .font(.system(size: 39, weight: .bold, design: .rounded))
                Text("C")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Sparkline(values: values, color: reading.condition.color, lineWidth: 2.5)
                .frame(height: 35)

            HStack {
                Text("\(Int(reading.fahrenheit.rounded()))°F")
                Spacer()
                Text(reading.sensorKey)
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.tertiary)
        }
        .padding(18)
        .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct Sparkline: View {
    let values: [Double]
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let points = chartPoints(in: proxy.size)

            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x, y: proxy.size.height))
                    for point in points {
                        path.addLine(to: point)
                    }
                    path.addLine(to: CGPoint(x: points.last?.x ?? 0, y: proxy.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.26), color.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        let displayValues = values.isEmpty ? [0.5, 0.5] : values
        let minimum = (displayValues.min() ?? 0) - 3
        let maximum = max((displayValues.max() ?? 1) + 3, minimum + 1)

        return displayValues.enumerated().map { index, value in
            let x = size.width * CGFloat(index) / CGFloat(max(displayValues.count - 1, 1))
            let progress = (value - minimum) / (maximum - minimum)
            let y = size.height - CGFloat(progress) * size.height
            return CGPoint(x: x, y: y)
        }
    }
}

private struct Stat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

private struct EmptyState: View {
    let message: String?

    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "thermometer.medium.slash")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Color(red: 0.35, green: 0.85, blue: 1))
            Text("Looking for temperatures")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(message ?? "MacTemp is opening your Mac sensor controller.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 120)
        .padding(.horizontal, 24)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
