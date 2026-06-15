import Foundation

public enum ModelServerClientError: LocalizedError, Equatable {
    case unauthenticated
    case invalidURL(String)
    case httpStatus(Int, String)
    case missingToken

    public var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "尚未登录或登录已失效"
        case .invalidURL(let path):
            return "接口 URL 无效：\(path)"
        case .httpStatus(let status, let body):
            return "接口请求失败：HTTP \(status) \(body)"
        case .missingToken:
            return "登录响应缺少 access_token 或 refresh_token"
        }
    }
}

public actor ModelServerClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenStore: TokenStore
    private var accessToken: String?
    private var refreshToken: String?
    private var shouldPersistRefreshToken = false

    public init(
        baseURL: URL = URL(string: "https://codeapi.cs.ac.cn")!,
        session: URLSession = .shared,
        tokenStore: TokenStore
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenStore = tokenStore
    }

    public nonisolated func authorizationURL(provider: String = AuthCallbackParser.defaultProvider) -> URL {
        URL(string: "https://codeapi.cs.ac.cn/api/v1/auth/oauth/\(provider)/redirect?provider=\(provider)")!
    }

    public nonisolated func hasSavedRefreshToken() -> Bool {
        (try? tokenStore.loadRefreshToken()) != nil
    }

    public func canAuthenticate() -> Bool {
        accessToken != nil || refreshToken != nil || hasSavedRefreshToken()
    }

    @discardableResult
    public func exchange(callback: OAuthCallback, persistRefreshToken: Bool = false) async throws -> AuthResponse {
        let body = AuthExchangeRequest(code: callback.code, state: callback.state)
        let response: AuthResponse = try await rawRequest(
            "/api/v1/auth/oauth/\(callback.provider)",
            method: "POST",
            body: try JSONEncoder().encode(body),
            requiresAuth: false
        )
        guard let accessToken = response.accessToken,
              let refreshToken = response.refreshToken else {
            throw ModelServerClientError.missingToken
        }
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.shouldPersistRefreshToken = persistRefreshToken
        if persistRefreshToken {
            try tokenStore.saveRefreshToken(refreshToken)
        }
        return response
    }

    public func signOut() throws {
        accessToken = nil
        refreshToken = nil
        shouldPersistRefreshToken = false
        try tokenStore.deleteRefreshToken()
    }

    public func fetchProjects() async throws -> [Project] {
        let envelope: APIEnvelope<[Project]> = try await request("/api/v1/projects?per_page=100")
        return envelope.data
    }

    public func fetchProject(id: String) async throws -> Project {
        let envelope: APIEnvelope<Project> = try await request("/api/v1/projects/\(id)")
        return envelope.data
    }

    public func fetchUsageOverview(projectId: String) async throws -> UsageOverviewDTO {
        let envelope: APIEnvelope<UsageOverviewDTO> = try await request("/api/v1/projects/\(projectId)/usage")
        return envelope.data
    }

    public func fetchDailyUsage(projectId: String) async throws -> [UsageBucketDTO] {
        let envelope: APIEnvelope<[UsageBucketDTO]> = try await request("/api/v1/projects/\(projectId)/usage?breakdown=daily")
        return envelope.data
    }

    public func fetchModelUsage(projectId: String) async throws -> [UsageBucketDTO] {
        let envelope: APIEnvelope<[UsageBucketDTO]> = try await request("/api/v1/projects/\(projectId)/usage?breakdown=model")
        return envelope.data
    }

    public func fetchRecentRequests(projectId: String) async throws -> [RecentRequestDTO] {
        let envelope: APIEnvelope<[RecentRequestDTO]> = try await request("/api/v1/projects/\(projectId)/requests?per_page=5")
        return envelope.data
    }

    public func fetchQuota(projectId: String) async throws -> QuotaDTO {
        let envelope: APIEnvelope<QuotaDTO> = try await request("/api/v1/projects/\(projectId)/my-quota")
        return envelope.data
    }

    public func fetchSubscriptionUsage(projectId: String) async throws -> [QuotaWindowDTO] {
        let envelope: APIEnvelope<[QuotaWindowDTO]> = try await request("/api/v1/projects/\(projectId)/subscription/usage")
        return envelope.data
    }

    private func request<T: Decodable>(_ path: String) async throws -> T {
        if accessToken == nil {
            try await refreshAccessToken()
        }

        do {
            return try await rawRequest(path, requiresAuth: true)
        } catch ModelServerClientError.httpStatus(let status, _) where status == 401 {
            try await refreshAccessToken()
            return try await rawRequest(path, requiresAuth: true)
        }
    }

    @discardableResult
    private func refreshAccessToken() async throws -> AuthResponse {
        let savedRefreshToken = refreshToken == nil ? (try tokenStore.loadRefreshToken()) : nil
        guard let refreshToken = refreshToken ?? savedRefreshToken else {
            throw ModelServerClientError.unauthenticated
        }
        let shouldPersist = shouldPersistRefreshToken || savedRefreshToken != nil

        do {
            let body = RefreshRequest(refreshToken: refreshToken)
            let response: AuthResponse = try await rawRequest(
                "/api/v1/auth/refresh",
                method: "POST",
                body: try JSONEncoder().encode(body),
                requiresAuth: false
            )
            guard let accessToken = response.accessToken,
                  let refreshToken = response.refreshToken else {
                throw ModelServerClientError.missingToken
            }
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.shouldPersistRefreshToken = shouldPersist
            if shouldPersist {
                try tokenStore.saveRefreshToken(refreshToken)
            }
            return response
        } catch {
            accessToken = nil
            if Self.shouldClearRefreshToken(after: error) {
                self.refreshToken = nil
                self.shouldPersistRefreshToken = false
                try? tokenStore.deleteRefreshToken()
            }
            throw error
        }
    }

    private static func shouldClearRefreshToken(after error: Error) -> Bool {
        guard case ModelServerClientError.httpStatus(let status, _) = error else {
            return false
        }
        return status == 400 || status == 401 || status == 403
    }

    private func rawRequest<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Data? = nil,
        requiresAuth: Bool
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw ModelServerClientError.invalidURL(path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if requiresAuth, let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let bodyText = String(data: data.prefix(400), encoding: .utf8) ?? ""
            throw ModelServerClientError.httpStatus(status, bodyText)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct AuthExchangeRequest: Encodable {
    let code: String
    let state: String?
}

private struct RefreshRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}
