import Foundation

public struct OAuthCallback: Equatable, Sendable {
    public let provider: String
    public let code: String
    public let state: String?

    public init(provider: String, code: String, state: String?) {
        self.provider = provider
        self.code = code
        self.state = state
    }
}

public enum AuthCallbackError: LocalizedError, Equatable {
    case invalidURL
    case missingProvider
    case missingCode

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "回调 URL 无效"
        case .missingProvider:
            return "回调 URL 缺少 provider"
        case .missingCode:
            return "回调 URL 缺少 code"
        }
    }
}

public enum AuthCallbackParser {
    public static let defaultProvider = "oidc"

    public static func parse(_ rawURL: String, fallbackProvider: String = defaultProvider) throws -> OAuthCallback {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AuthCallbackError.invalidURL
        }

        let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        guard let code, !code.isEmpty else {
            throw AuthCallbackError.missingCode
        }

        let state = components.queryItems?.first(where: { $0.name == "state" })?.value
        let provider = providerFromPath(url.path) ?? fallbackProvider
        guard !provider.isEmpty else {
            throw AuthCallbackError.missingProvider
        }

        return OAuthCallback(provider: provider, code: code, state: state)
    }

    private static func providerFromPath(_ path: String) -> String? {
        let parts = path.split(separator: "/").map(String.init)
        guard let callbackIndex = parts.firstIndex(of: "callback"),
              parts.indices.contains(callbackIndex + 1) else {
            return nil
        }
        return parts[callbackIndex + 1]
    }
}
