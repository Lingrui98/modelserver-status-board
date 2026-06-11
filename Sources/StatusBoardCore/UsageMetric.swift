import Foundation

public struct UsageMetric: Equatable, Sendable {
    public enum Kind: Sendable {
        case requests
        case tokens
        case creditsK
        case currencyFen
        case latencyMilliseconds
        case percentage
        case plain
    }

    public let rawValue: Double
    public let kind: Kind

    public init(_ rawValue: Double, kind: Kind) {
        self.rawValue = rawValue
        self.kind = kind
    }

    public var formatted: String {
        switch kind {
        case .requests, .tokens, .plain:
            return Self.compact(rawValue)
        case .creditsK:
            return "\(Self.integer(rawValue))K"
        case .currencyFen:
            return "¥\(Self.decimal(rawValue / 100, fractionDigits: 2))"
        case .latencyMilliseconds:
            return "\(Int(rawValue.rounded()))ms"
        case .percentage:
            return "\(Self.decimal(rawValue, fractionDigits: 2))%"
        }
    }

    public static func compact(_ value: Double) -> String {
        let absolute = abs(value)
        if absolute >= 1_000_000 {
            return trimmed(value / 1_000_000) + "M"
        }
        if absolute >= 1_000 {
            return trimmed(value / 1_000) + "K"
        }
        return integer(value)
    }

    public static func integer(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
    }

    public static func decimal(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(fractionDigits)f", value)
    }

    private static func trimmed(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}
