import Foundation

/// Centralized utility for calculating usage status levels with configurable display modes
final class UsageStatusCalculator {

    /// Calculate status level based on percentage and display mode
    /// - Parameters:
    ///   - usedPercentage: The percentage used (0-100)
    ///   - showRemaining: If true, use remaining-based thresholds; if false, use used-based thresholds
    /// - Returns: The appropriate status level
    static func calculateStatus(
        usedPercentage: Double,
        showRemaining: Bool
    ) -> UsageStatusLevel {
        if showRemaining {
            // Based on remaining percentage (like Mac battery)
            // > 25% remaining: safe (green)
            // 10-25% remaining: warning (yellow)
            // 5-10% remaining: moderate (orange)
            // < 5% remaining: critical (red)
            let remainingPercentage = max(0, 100 - usedPercentage)
            switch remainingPercentage {
            case 25...:
                return .safe
            case 10..<25:
                return .warning
            case 5..<10:
                return .moderate
            default:
                return .critical
            }
        } else {
            // Based on used percentage
            // 0-75% used: safe (green)
            // 75-90% used: warning (yellow)
            // 90-95% used: moderate (orange)
            // 95-100% used: critical (red)
            switch usedPercentage {
            case 0..<75:
                return .safe
            case 75..<90:
                return .warning
            case 90..<95:
                return .moderate
            default:
                return .critical
            }
        }
    }

    /// Get the display percentage based on mode
    /// - Parameters:
    ///   - usedPercentage: The percentage used (0-100)
    ///   - showRemaining: If true, return remaining percentage; if false, return used percentage
    /// - Returns: The percentage to display
    static func getDisplayPercentage(
        usedPercentage: Double,
        showRemaining: Bool
    ) -> Double {
        if showRemaining {
            return max(0, 100 - usedPercentage)
        } else {
            return usedPercentage
        }
    }
}
