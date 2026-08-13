import AuthenticationServices
import CommonCrypto
import Foundation
import UIKit

final class GoogleAuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    struct TokenSet: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Date
    }

    private let keychain: KeychainStore
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
        guard let access = keychain.get(.googleAccessToken),
              let refresh = keychain.get(.googleRefreshToken),
              let expiresText = keychain.get(.googleExpiresAt),
              let expiresAt = ISO8601DateFormatter().date(from: expiresText) else {
            return nil
        }
        return TokenSet(accessToken: access, refreshToken: refresh, expiresAt: expiresAt)
    }

    func clearTokens() {
        keychain.clearGoogle()
    }

    func authorize() async throws -> TokenSet {
        guard GoogleHealthConfig.isConfigured else {
            throw NSError(
                domain: "GoogleAuth",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Google Health API client ID is not configured yet."]
            )
        }
        let codeVerifier = Self.randomString(length: 64)
        let challenge = Self.base64URLEncode(Self.sha256(data: Data(codeVerifier.utf8)))
        verifier = codeVerifier

        var components = URLComponents(string: GoogleHealthConfig.authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: GoogleHealthConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: GoogleHealthConfig.redirectURI),
            URLQueryItem(name: "scope", value: GoogleHealthConfig.scopes),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        let code = try await runWebAuth(url: components.url!)
        let token = try await exchangeCodeForToken(code: code)
        persist(token: token)
        keychain.set(HealthAuthProvider.google.rawValue, for: .oauthProvider)
        return token
    }

    func validAccessToken() async throws -> String {
        guard let tokenSet else {
            throw NSError(domain: "GoogleAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not connected to Google Health"])
        }
        if tokenSet.expiresAt > Date().addingTimeInterval(60) {
            return tokenSet.accessToken
        }
        let refreshed = try await refresh(refreshToken: tokenSet.refreshToken)
        persist(token: refreshed)
        return refreshed.accessToken
    }

    private func runWebAuth(url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            authSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: GoogleHealthConfig.callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: NSError(domain: "GoogleAuth", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing OAuth code"]))
                    return
                }
                continuation.resume(returning: code)
            }
            authSession?.prefersEphemeralWebBrowserSession = false
            authSession?.presentationContextProvider = self
            if authSession?.start() == false {
                continuation.resume(throwing: NSError(domain: "GoogleAuth", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to start login"]))
            }
        }
    }

    private func exchangeCodeForToken(code: String) async throws -> TokenSet {
        let body = [
            "client_id": GoogleHealthConfig.clientID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": GoogleHealthConfig.redirectURI,
            "code_verifier": verifier
        ]
        return try await performTokenRequest(body: body)
    }

    private func refresh(refreshToken: String) async throws -> TokenSet {
        let body = [
            "client_id": GoogleHealthConfig.clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        return try await performTokenRequest(body: body, fallbackRefresh: refreshToken)
    }

    private func performTokenRequest(body: [String: String], fallbackRefresh: String? = nil) async throws -> TokenSet {
        var request = URLRequest(url: URL(string: GoogleHealthConfig.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "GoogleAuth", code: 4, userInfo: [NSLocalizedDescriptionKey: "Google token request failed"])
        }
        struct TokenResponse: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Int
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        let refresh = decoded.refresh_token ?? fallbackRefresh ?? ""
        guard !refresh.isEmpty else {
            throw NSError(domain: "GoogleAuth", code: 5, userInfo: [NSLocalizedDescriptionKey: "Google refresh token missing"])
        }
        return TokenSet(
            accessToken: decoded.access_token,
            refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(TimeInterval(decoded.expires_in))
        )
    }

    private func persist(token: TokenSet) {
        let formatter = ISO8601DateFormatter()
        keychain.set(token.accessToken, for: .googleAccessToken)
        keychain.set(token.refreshToken, for: .googleRefreshToken)
        keychain.set(formatter.string(from: token.expiresAt), for: .googleExpiresAt)
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
