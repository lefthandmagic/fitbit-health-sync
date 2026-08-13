import Foundation

/// Google Cloud OAuth iOS client for the Google Health API.
/// Paste the iOS client ID from https://console.cloud.google.com after enabling Google Health API.
/// Then add the reversed client ID as a URL scheme in Info.plist (see README).
enum GoogleHealthConfig {
    static let clientID = "547556030049-csoh2cpvu82k3ub8b0gie0gk2k7mhhgc.apps.googleusercontent.com"

    static var isConfigured: Bool { !clientID.isEmpty }

    static var reversedClientID: String { reversedClientID(from: clientID) }

    static func reversedClientID(from clientID: String) -> String {
        clientID.split(separator: ".").reversed().map(String.init).joined(separator: ".")
    }

    static var redirectURI: String { "\(reversedClientID):/oauth2redirect" }

    static var callbackScheme: String { reversedClientID }

    static let authorizeURL = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenURL = "https://oauth2.googleapis.com/token"
    static let apiBase = "https://health.googleapis.com/v4"

    static let scopes = [
        "https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly",
        "https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly",
        "https://www.googleapis.com/auth/googlehealth.sleep.readonly"
    ].joined(separator: " ")
}
