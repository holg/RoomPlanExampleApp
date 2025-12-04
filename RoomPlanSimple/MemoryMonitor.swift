/*
See LICENSE folder for this sample's licensing information.

Abstract:
Debug-only memory monitoring utility for detecting leaks (Issue #15).
*/

import Foundation

#if DEBUG

/// Debug-only memory monitor for tracking memory usage and detecting potential leaks.
/// Only compiled in DEBUG builds - has zero overhead in release builds.
@MainActor
final class MemoryMonitor {

    static let shared = MemoryMonitor()

    private var isMonitoring = false
    private var timer: Timer?
    private var baselineMemory: UInt64 = 0
    private var peakMemory: UInt64 = 0

    private init() {}

    // MARK: - Public API

    /// Start monitoring memory usage with periodic logging
    func startMonitoring(interval: TimeInterval = 5.0) {
        guard !isMonitoring else { return }
        isMonitoring = true
        baselineMemory = currentMemoryUsage()
        peakMemory = baselineMemory

        print("📊 [MemoryMonitor] Started - Baseline: \(formatBytes(baselineMemory))")

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.logMemoryStatus()
            }
        }
    }

    /// Stop monitoring
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        print("📊 [MemoryMonitor] Stopped - Peak: \(formatBytes(peakMemory))")
    }

    /// Log current memory status
    func logMemoryStatus() {
        let current = currentMemoryUsage()
        peakMemory = max(peakMemory, current)

        let delta = Int64(current) - Int64(baselineMemory)
        let deltaStr = delta >= 0 ? "+\(formatBytes(UInt64(delta)))" : "-\(formatBytes(UInt64(-delta)))"

        print("📊 [MemoryMonitor] Current: \(formatBytes(current)) | Delta: \(deltaStr) | Peak: \(formatBytes(peakMemory))")
    }

    /// Log a checkpoint with custom label
    func checkpoint(_ label: String) {
        let current = currentMemoryUsage()
        print("📊 [MemoryMonitor] \(label): \(formatBytes(current))")
    }

    /// Check if memory increased significantly (potential leak indicator)
    func checkForLeaks(threshold: UInt64 = 50_000_000) -> Bool {
        let current = currentMemoryUsage()
        let increase = current > baselineMemory ? current - baselineMemory : 0

        if increase > threshold {
            print("⚠️ [MemoryMonitor] Potential leak detected! Increase: \(formatBytes(increase))")
            return true
        }
        return false
    }

    // MARK: - Private

    private func currentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_000_000.0
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Convenience Extensions

extension MemoryMonitor {
    /// Track a scope's memory impact
    func track<T>(_ label: String, operation: () -> T) -> T {
        let before = currentMemoryUsage()
        let result = operation()
        let after = currentMemoryUsage()
        let delta = Int64(after) - Int64(before)
        let sign = delta >= 0 ? "+" : ""
        print("📊 [MemoryMonitor] \(label): \(sign)\(formatBytes(UInt64(abs(delta))))")
        return result
    }
}

#else

// Release build stub - completely empty, zero overhead
@MainActor
final class MemoryMonitor {
    static let shared = MemoryMonitor()
    private init() {}

    @inlinable func startMonitoring(interval: TimeInterval = 5.0) {}
    @inlinable func stopMonitoring() {}
    @inlinable func logMemoryStatus() {}
    @inlinable func checkpoint(_ label: String) {}
    @inlinable func checkForLeaks(threshold: UInt64 = 50_000_000) -> Bool { false }
    @inlinable func track<T>(_ label: String, operation: () -> T) -> T { operation() }
}

#endif
