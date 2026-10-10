import Foundation

/// Weights are stored in pounds; display converts (SPEC 9.1).
public enum WeightUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case lb, kg

    public var id: String { rawValue }

    public static let poundsPerKilogram = 2.20462262185

    /// Size of one +/- step, in pounds (SPEC 5.6: 5 lb or 2.5 kg).
    public var stepLb: Double {
        self == .lb ? 5 : 2.5 * WeightUnit.poundsPerKilogram
    }

    /// Converts a stored pound value to this unit, rounded to the nearest 0.5.
    public func display(fromLb lb: Double) -> Double {
        let value = self == .lb ? lb : lb / WeightUnit.poundsPerKilogram
        return (value * 2).rounded() / 2
    }

    public func toLb(_ value: Double) -> Double {
        self == .lb ? value : value * WeightUnit.poundsPerKilogram
    }
}

public enum WeightFormat {
    public static func number(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    /// "135 lb", "BW", "BW + 25 lb" (SPEC 3.6).
    public static func text(lb: Double, bodyweight: Bool, unit: WeightUnit) -> String {
        let shown = unit.display(fromLb: lb)
        let amount = number(shown) + " " + unit.rawValue
        if bodyweight {
            return shown > 0 ? "BW + " + amount : "BW"
        }
        return amount
    }

    /// Adjusts a pound value by one step, never below 0.
    public static func step(_ lb: Double, by steps: Int, unit: WeightUnit) -> Double {
        let next = lb + Double(steps) * unit.stepLb
        return max(0, (next * 1000).rounded() / 1000)
    }
}

public enum DurationFormat {
    /// 90 → "1:30"
    public static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
