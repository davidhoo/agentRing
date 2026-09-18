import Foundation
import CoreGraphics

// Test fixture verifying ring display math for both remaining and used modes.

struct UsageRingTrimRange: Equatable {
    let from: CGFloat
    let to: CGFloat
}

enum UsageRingDisplay {
    static func clampedPercentage(_ percentage: Double) -> Double { min(100, max(0, percentage)) }
    static func remainingPercentage(usedPercentage: Double) -> Double { 100 - clampedPercentage(usedPercentage) }
    static func displayedPercentage(usedPercentage: Double, showRemainingMode: Bool) -> Double {
        let used = clampedPercentage(usedPercentage)
        return showRemainingMode ? remainingPercentage(usedPercentage: used) : used
    }
    static func usedFraction(_ usedPercentage: Double) -> CGFloat { CGFloat(clampedPercentage(usedPercentage) / 100.0) }
    static func displayedTrimRange(usedPercentage: Double, showRemainingMode: Bool) -> UsageRingTrimRange {
        let used = usedFraction(usedPercentage)
        if showRemainingMode { return UsageRingTrimRange(from: 0, to: 1 - used) }
        return UsageRingTrimRange(from: 0, to: used)
    }
    static func trackTrimRange(usedPercentage: Double, showRemainingMode: Bool) -> UsageRingTrimRange? {
        let displayedRange = displayedTrimRange(usedPercentage: usedPercentage, showRemainingMode: showRemainingMode)
        guard displayedRange.to < 0.998 else { return nil }
        return UsageRingTrimRange(from: displayedRange.to, to: 1)
    }
    static func usedPortionTrimRange(usedPercentage: Double, showRemainingMode: Bool) -> UsageRingTrimRange? {
        trackTrimRange(usedPercentage: usedPercentage, showRemainingMode: showRemainingMode)
    }
    static func percentLabel(usedPercentage: Double, showRemainingMode: Bool) -> String {
        let displayed = displayedPercentage(
            usedPercentage: usedPercentage,
            showRemainingMode: showRemainingMode
        )
        let rounded: Int = {
            if displayed < 0.2 { return 0 }
            if displayed < 1.0 { return 1 }
            if displayed >= 99.0 && displayed <= 99.8 { return 99 }
            if displayed > 99.8 { return 100 }
            return Int(displayed.rounded())
        }()
        return "\(rounded)%"
    }
}

func check(_ cond: Bool, _ msg: String) {
    if !cond {
        fputs("FAIL: \(msg)\n", stderr)
        exit(1)
    }
    print("PASS: \(msg)")
}

// 1. Used mode: 0% used
let u0 = UsageRingDisplay.displayedTrimRange(usedPercentage: 0, showRemainingMode: false)
let t0 = UsageRingDisplay.trackTrimRange(usedPercentage: 0, showRemainingMode: false)
check(u0 == UsageRingTrimRange(from: 0, to: 0), "used mode 0% solid is empty")
check(t0 == UsageRingTrimRange(from: 0, to: 1), "used mode 0% track is full circle")

// 2. Used mode: 30% used
let u30 = UsageRingDisplay.displayedTrimRange(usedPercentage: 30, showRemainingMode: false)
let t30 = UsageRingDisplay.trackTrimRange(usedPercentage: 30, showRemainingMode: false)
check(u30 == UsageRingTrimRange(from: 0, to: 0.3), "used mode 30% solid is 0..0.3")
check(t30 == UsageRingTrimRange(from: 0.3, to: 1.0), "used mode 30% track is 0.3..1.0")

// 3. Used mode: 100% used
let u100 = UsageRingDisplay.displayedTrimRange(usedPercentage: 100, showRemainingMode: false)
let t100 = UsageRingDisplay.trackTrimRange(usedPercentage: 100, showRemainingMode: false)
check(u100 == UsageRingTrimRange(from: 0, to: 1.0), "used mode 100% solid is full circle")
check(t100 == nil, "used mode 100% track is nil")

// 4. Remaining mode: 0% used (100% remaining)
let r0 = UsageRingDisplay.displayedTrimRange(usedPercentage: 0, showRemainingMode: true)
let rt0 = UsageRingDisplay.trackTrimRange(usedPercentage: 0, showRemainingMode: true)
check(r0 == UsageRingTrimRange(from: 0, to: 1.0), "remaining mode 0% used solid is full circle")
check(rt0 == nil, "remaining mode 0% used track is nil")

// 5. Remaining mode: 30% used (70% remaining)
let r30 = UsageRingDisplay.displayedTrimRange(usedPercentage: 30, showRemainingMode: true)
let rt30 = UsageRingDisplay.trackTrimRange(usedPercentage: 30, showRemainingMode: true)
check(r30 == UsageRingTrimRange(from: 0, to: 0.7), "remaining mode 30% used solid is 0..0.7")
check(rt30 == UsageRingTrimRange(from: 0.7, to: 1.0), "remaining mode 30% used track is 0.7..1.0")

// 6. Remaining mode: 100% used (0% remaining)
let r100 = UsageRingDisplay.displayedTrimRange(usedPercentage: 100, showRemainingMode: true)
let rt100 = UsageRingDisplay.trackTrimRange(usedPercentage: 100, showRemainingMode: true)
check(r100 == UsageRingTrimRange(from: 0, to: 0), "remaining mode 100% used solid is empty")
check(rt100 == UsageRingTrimRange(from: 0, to: 1), "remaining mode 100% used track is full circle")

// 7. Threshold checks near 100%
check(UsageRingDisplay.trackTrimRange(usedPercentage: 99.9, showRemainingMode: false) == nil, "used mode 99.9% track suppressed")
check(UsageRingDisplay.trackTrimRange(usedPercentage: 99.7, showRemainingMode: false) != nil, "used mode 99.7% track retained")

// 8. Legacy alias compatibility
check(UsageRingDisplay.usedPortionTrimRange(usedPercentage: 30, showRemainingMode: false) == t30, "usedPortionTrimRange alias matches trackTrimRange")

// 9. Percentage formatting with edge protection & rounding (threshold: 0.2%)
// Remaining mode (showRemainingMode: true):
// 100% used -> 0% remaining
check(UsageRingDisplay.percentLabel(usedPercentage: 100.0, showRemainingMode: true) == "0%", "100% used is 0% remaining")
// 99.9% used (0.1% remaining < 0.2%) -> 0%
check(UsageRingDisplay.percentLabel(usedPercentage: 99.9, showRemainingMode: true) == "0%", "0.1% remaining (<0.2%) is 0%")
// 99.8% used (0.2% remaining >= 0.2%) -> non-zero floor 1%
check(UsageRingDisplay.percentLabel(usedPercentage: 99.8, showRemainingMode: true) == "1%", "0.2% remaining has non-zero floor 1%")
// 99.715556% used (0.284444% remaining) -> non-zero floor 1%
check(UsageRingDisplay.percentLabel(usedPercentage: 99.715556, showRemainingMode: true) == "1%", "0.28% remaining has non-zero floor 1%")
// 99.4% used (0.6% remaining) -> rounds to 1%
check(UsageRingDisplay.percentLabel(usedPercentage: 99.4, showRemainingMode: true) == "1%", "0.6% remaining rounds to 1%")
// 98.6% used (1.4% remaining) -> rounds to 1%
check(UsageRingDisplay.percentLabel(usedPercentage: 98.6, showRemainingMode: true) == "1%", "1.4% remaining rounds to 1%")
// 98.4% used (1.6% remaining) -> rounds to 2%
check(UsageRingDisplay.percentLabel(usedPercentage: 98.4, showRemainingMode: true) == "2%", "1.6% remaining rounds to 2%")
// 0.2% used (99.8% remaining) -> capped at 99%
check(UsageRingDisplay.percentLabel(usedPercentage: 0.2, showRemainingMode: true) == "99%", "99.8% remaining capped at 99%")
// 0.1% used (99.9% remaining > 99.8%) -> 100%
check(UsageRingDisplay.percentLabel(usedPercentage: 0.1, showRemainingMode: true) == "100%", "99.9% remaining is 100%")
// 0.0% used (100% remaining) -> 100%
check(UsageRingDisplay.percentLabel(usedPercentage: 0.0, showRemainingMode: true) == "100%", "0.0% used is 100% remaining")

// Used mode (showRemainingMode: false):
check(UsageRingDisplay.percentLabel(usedPercentage: 0.0, showRemainingMode: false) == "0%", "0% used is 0%")
check(UsageRingDisplay.percentLabel(usedPercentage: 0.1, showRemainingMode: false) == "0%", "0.1% used (<0.2%) is 0%")
check(UsageRingDisplay.percentLabel(usedPercentage: 0.2, showRemainingMode: false) == "1%", "0.2% used has non-zero floor 1%")
check(UsageRingDisplay.percentLabel(usedPercentage: 99.8, showRemainingMode: false) == "99%", "99.8% used capped at 99%")
check(UsageRingDisplay.percentLabel(usedPercentage: 99.9, showRemainingMode: false) == "100%", "99.9% used is 100%")
check(UsageRingDisplay.percentLabel(usedPercentage: 100.0, showRemainingMode: false) == "100%", "100% used is 100%")

print("All ring display checks passed.")
