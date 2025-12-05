//
//  Secrets.swift
//  RoomPlanSimple
//
//  Environment variable loader - reads from .env file (Linux backend style)
//  This file is gitignored - create from Secrets.swift.example if missing
//

import Foundation

/// Manages loading and accessing environment variables from .env file
/// Similar to dotenv in Node.js or python-dotenv
enum Secrets {

    // MARK: - Environment Variables

    /// Example: API key for external service
    /// Usage: Secrets.apiKey
    static var apiKey: String? {
        return get("API_KEY")
    }

    /// Example: Google Maps API key
    static var googleMapsApiKey: String? {
        return get("GOOGLE_MAPS_API_KEY")
    }

    /// Example: Backend API base URL
    static var apiBaseURL: String? {
        return get("API_BASE_URL")
    }

    /// Example: Feature flag for analytics
    static var analyticsEnabled: Bool {
        return getBool("ENABLE_ANALYTICS", default: false)
    }

    // MARK: - Add your own secrets above this line

    // MARK: - Private Implementation

    /// Cached environment variables loaded from .env file
    private static var environment: [String: String] = {
        loadEnvironment()
    }()

    /// Get string value from environment
    private static func get(_ key: String) -> String? {
        // 1. Try ProcessInfo (for Xcode schemes or command-line args)
        if let value = ProcessInfo.processInfo.environment[key] {
            return value
        }

        // 2. Try .env file
        return environment[key]
    }

    /// Get boolean value from environment
    private static func getBool(_ key: String, default defaultValue: Bool) -> Bool {
        guard let value = get(key)?.lowercased() else {
            return defaultValue
        }
        return ["true", "1", "yes", "on"].contains(value)
    }

    /// Get integer value from environment
    private static func getInt(_ key: String, default defaultValue: Int) -> Int {
        guard let value = get(key), let intValue = Int(value) else {
            return defaultValue
        }
        return intValue
    }

    /// Load .env file from project root
    private static func loadEnvironment() -> [String: String] {
        var env: [String: String] = [:]

        // Find .env file in common locations
        let possiblePaths = [
            // Development (Xcode runs from DerivedData, so we need to find project root)
            Bundle.main.bundlePath + "/../../../../../.env",
            // Installed app (less common, but bundle may have .env copied)
            Bundle.main.path(forResource: ".env", ofType: nil),
            // Fallback to Documents directory
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(".env").path
        ].compactMap { $0 }

        for path in possiblePaths {
            if let contents = try? String(contentsOfFile: path, encoding: .utf8) {
                env = parseEnvFile(contents)
                #if DEBUG
                print("[Secrets] Loaded .env from: \(path)")
                print("[Secrets] Found \(env.count) variables")
                #endif
                break
            }
        }

        #if DEBUG
        if env.isEmpty {
            print("[Secrets] Warning: No .env file found. Searched paths:")
            possiblePaths.forEach { print("  - \($0)") }
        }
        #endif

        return env
    }

    /// Parse .env file contents into dictionary
    private static func parseEnvFile(_ contents: String) -> [String: String] {
        var env: [String: String] = [:]

        let lines = contents.components(separatedBy: .newlines)

        for line in lines {
            // Skip empty lines and comments
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Parse KEY=VALUE
            let parts = trimmed.components(separatedBy: "=")
            guard parts.count >= 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1...].joined(separator: "=") // Handle = in values
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) // Remove quotes

            env[key] = value
        }

        return env
    }

    // MARK: - Debug Helper

    #if DEBUG
    /// Print all loaded environment variables (for debugging)
    static func printAll() {
        print("=== Environment Variables ===")
        if environment.isEmpty {
            print("(none loaded)")
        } else {
            for (key, value) in environment.sorted(by: { $0.key < $1.key }) {
                // Mask sensitive values in output
                let maskedValue = maskSensitiveValue(key: key, value: value)
                print("\(key) = \(maskedValue)")
            }
        }
        print("=============================")
    }

    private static func maskSensitiveValue(key: String, value: String) -> String {
        let sensitivePatterns = ["KEY", "SECRET", "TOKEN", "PASSWORD", "CREDENTIAL"]
        let isSensitive = sensitivePatterns.contains { key.uppercased().contains($0) }

        if isSensitive && value.count > 4 {
            let prefix = String(value.prefix(2))
            let suffix = String(value.suffix(2))
            return "\(prefix)***\(suffix)"
        }
        return value
    }
    #endif
}
