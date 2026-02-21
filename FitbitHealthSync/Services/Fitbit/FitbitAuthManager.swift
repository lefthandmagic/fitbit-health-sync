import AuthenticationServices
import CommonCrypto
import Foundation
import UIKit

final class FitbitAuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    struct TokenSet: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Date
    }

    private let keychain: KeychainStore
    private let redirectScheme = "fitbithealthsync"
    private let callbackPath = "oauth-callback"

    private var authSession: ASWebAuthenticationSession?
    private var verifier = ""

    init(keychain: KeychainStore) {
        self.keychain = keychain
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first ?? ASPresentationAnchor()
    }

    var tokenSet: TokenSet? {
        guard let access = keychain.get(.accessToken),
              let refresh = keychain.get(.refreshToken),
              let expiresText = keychain.get(.expiresAt),
              let expiresAt = ISO8601DateFormatter().date(from: expiresText) else {
            return nil
        }
        return TokenSet(accessToken: access, refreshToken: refresh, expiresAt: expiresAt)
    }

    func clearTokens() {
        keychain.clearAll()
    }

    func authorize(clientID: String) async throws -> TokenSet {
        let codeVerifier = Self.randomString(length: 64)
        let challenge = Self.base64URLEncode(Self.sha256(data: Data(codeVerifier.utf8)))
        verifier = codeVerifier

        var components = URLComponents(string: "https://www.fitbit.com/oauth2/authorize")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: "\(redirectScheme)://\(callbackPath)"),
            URLQueryItem(name: "scope", value: "weight heartrate activity sleep"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        let code = try await runWebAuth(url: components.url!)
        let token = try await exchangeCodeForToken(code: code, clientID: clientID)
        persist(token: token)
        return token
    }

    func validAccessToken(clientID: String) async throws -> String {
        guard let tokenSet else {
            throw NSError(domain: "FitbitAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not connected to Fitbit"])
        }
        if tokenSet.expiresAt > Date().addingTimeInterval(60) {
            return tokenSet.accessToken
        }
        let refreshed = try await refresh(refreshToken: tokenSet.refreshToken, clientID: clientID)
        persist(token: refreshed)
        return refreshed.accessToken
    }

    private func runWebAuth(url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: redirectScheme) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: NSError(domain: "FitbitAuth", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing OAuth code"]))
                    return
                }
                continuation.resume(returning: code)
            }
            authSession?.prefersEphemeralWebBrowserSession = false
            authSession?.presentationContextProvider = self
            if authSession?.start() == false {
                continuation.resume(throwing: NSError(domain: "FitbitAuth", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to start login"]))
            }
        }
    }

    private func exchangeCodeForToken(code: String, clientID: String) async throws -> TokenSet {
        let body = [
            "client_id": clientID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": "\(redirectScheme)://\(callbackPath)",
            "code_verifier": verifier
        ]
        return try await performTokenRequest(body: body)
    }

    private func refresh(refreshToken: String, clientID: String) async throws -> TokenSet {
        let body = [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        return try await performTokenRequest(body: body)
    }

    private func performTokenRequest(body: [String: String]) async throws -> TokenSet {
        var request = URLRequest(url: URL(string: "https://api.fitbit.com/oauth2/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "FitbitAuth", code: 4, userInfo: [NSLocalizedDescriptionKey: "Token request failed"])
        }
        struct TokenResponse: Decodable {
            let access_token: String
            let refresh_token: String
            let expires_in: Int
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        return TokenSet(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token,
            expiresAt: Date().addingTimeInterval(TimeInterval(decoded.expires_in))
        )
    }

    private func persist(token: TokenSet) {
        let formatter = ISO8601DateFormatter()
        keychain.set(token.accessToken, for: .accessToken)
        keychain.set(token.refreshToken, for: .refreshToken)
        keychain.set(formatter.string(from: token.expiresAt), for: .expiresAt)
    }

    private static func randomString(length: Int) -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }

    private static func sha256(data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
