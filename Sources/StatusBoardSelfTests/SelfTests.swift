import Foundation
import StatusBoardCore

@main
enum StatusBoardSelfTests {
    static func main() async {
        var runner = TestRunner()
        await runner.run("callback parser") {
            try testCallbackParser()
        }
        await runner.run("missing callback code") {
            try testMissingCallbackCode()
        }
        await runner.run("quota remaining clamp") {
            try testQuotaRemainingClamp()
        }
        await runner.run("status title uses usage") {
            try testStatusTitleUsesUsage()
        }
        await runner.run("normalizes missing fields") {
            try testNormalizesMissingFields()
        }
        await runner.run("formats metrics and costs") {
            try testFormatsMetricsAndCosts()
        }
        await runner.run("refreshes token before request") {
            try await testRefreshesTokenBeforeRequest()
        }
        await runner.run("retries after unauthorized") {
            try await testRetriesAfterUnauthorized()
        }
        await runner.run("refresh failure clears token") {
            try await testRefreshFailureClearsToken()
        }
        await runner.run("network refresh failure preserves token") {
            try await testNetworkRefreshFailurePreservesToken()
        }
        await runner.run("session login does not save keychain token") {
            try await testSessionLoginDoesNotSaveKeychainToken()
        }
        runner.finish()
    }

    private static func testCallbackParser() throws {
        let callback = try AuthCallbackParser.parse("https://code.cs.ac.cn/auth/callback/oidc?code=abc%20123&state=s-1")
        try expect(callback.provider == "oidc", "provider should be oidc")
        try expect(callback.code == "abc 123", "code should be URL-decoded")
        try expect(callback.state == "s-1", "state should be preserved")

        let fallback = try AuthCallbackParser.parse("https://localhost/callback?code=abc", fallbackProvider: "oidc")
        try expect(fallback.provider == "oidc", "fallback provider should be used")
    }

    private static func testMissingCallbackCode() throws {
        do {
            _ = try AuthCallbackParser.parse("https://code.cs.ac.cn/auth/callback/oidc?state=s")
            throw TestFailure("expected missing code error")
        } catch AuthCallbackError.missingCode {
            return
        } catch {
            throw TestFailure("unexpected error: \(error)")
        }
    }

    private static func testQuotaRemainingClamp() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let windows = DashboardNormalizer.normalizeQuotaWindows(
            quota: nil,
            subscriptionUsage: [
                QuotaWindowDTO(window: "5h", percentage: 125, resetsAt: "1970-01-01T00:30:00Z")
            ],
            now: now
        )

        try expect(windows.first?.usedPercent == 125, "used percent should preserve observed value")
        try expect(windows.first?.remainingPercent == 0, "remaining percent should not go negative")
    }

    private static func testStatusTitleUsesUsage() throws {
        let state = DashboardState(
            quotaWindows: [
                QuotaWindow(label: "5h", usedPercent: 12.4, resetAt: nil),
                QuotaWindow(label: "7d", usedPercent: 56.6, resetAt: nil)
            ]
        )

        try expect(state.statusTitle == "5h 已用 12% · 7d 已用 57%", "status title should show used quota")
    }

    private static func testNormalizesMissingFields() throws {
        let state = DashboardNormalizer.makeState(
            project: Project(id: "p1", name: "Project X"),
            overview: UsageOverviewDTO(),
            dailyUsage: [UsageBucketDTO(date: "2026-06-11")],
            modelUsage: [UsageBucketDTO(model: "gpt-5.5")],
            recentRequests: [RecentRequestDTO(id: "r1")],
            quota: nil,
            subscriptionUsage: [],
            now: Date(timeIntervalSince1970: 0)
        )

        try expect(state.projectName == "Project X", "project name should be preserved")
        try expect(state.totals.requests.rawValue == 0, "missing request count should default to 0")
        try expect(state.dailyUsage.first?.requestCount == 0, "missing daily count should default to 0")
        try expect(state.modelUsage.first?.model == "gpt-5.5", "model name should be preserved")
        try expect(state.recentRequests.first?.model == "unknown", "missing request model should be unknown")
    }

    private static func testFormatsMetricsAndCosts() throws {
        let state = DashboardNormalizer.makeState(
            project: Project(id: "p1", name: "Project X"),
            overview: UsageOverviewDTO(
                requestCount: 8_800,
                totalTokens: 101_800_000,
                totalCreditsK: 49_106,
                periodSource: "subscription",
                costBreakdown: CostBreakdownDTO(
                    apiStandardFen: 662_614,
                    actualPaidFen: 59_999,
                    subscriptionFen: 59_999,
                    extraUsageFen: 0,
                    savedFen: 602_615,
                    hasActiveSubscription: true,
                    periodStart: "2026-05-20T00:00:00Z",
                    periodEnd: "2026-06-20T00:00:00Z"
                )
            ),
            dailyUsage: [
                UsageBucketDTO(date: "2026-06-10", requestCount: 100),
                UsageBucketDTO(date: "2026-06-11", requestCount: 300)
            ],
            modelUsage: [],
            recentRequests: [],
            quota: nil,
            subscriptionUsage: [],
            now: Date(timeIntervalSince1970: 0)
        )

        try expect(state.totals.requests.formatted == "8.8K", "requests should be compact")
        try expect(state.totals.tokens.formatted == "101.8M", "tokens should be compact")
        try expect(state.totals.averageDailyRequests.rawValue == 200, "average daily requests should be computed")
        try expect(state.costs?.apiStandardPrice.formatted == "¥6,626.14", "standard price should format yuan")
        try expect(state.costs?.periodPaid.formatted == "¥599.99", "period paid should format yuan")
    }

    private static func testRefreshesTokenBeforeRequest() async throws {
        let store = InMemoryTokenStore(token: "refresh-1")
        let client = ModelServerClient(
            baseURL: URL(string: "https://example.test")!,
            session: stubbedSession(),
            tokenStore: store
        )

        var seenAuthorization: String?
        URLProtocolStub.handler = { request in
            if request.url?.path == "/api/v1/auth/refresh" {
                return jsonResponse([
                    "access_token": "access-1",
                    "refresh_token": "refresh-2"
                ], status: 200)
            }

            seenAuthorization = request.value(forHTTPHeaderField: "Authorization")
            return jsonResponse([
                "data": [
                    "id": "p1",
                    "name": "Project X"
                ]
            ], status: 200)
        }

        let project = try await client.fetchProject(id: "p1")
        let savedRefreshToken = try store.loadRefreshToken()

        try expect(project.name == "Project X", "project response should decode")
        try expect(seenAuthorization == "Bearer access-1", "request should use refreshed access token")
        try expect(savedRefreshToken == "refresh-2", "refresh token should be rotated")
    }

    private static func testRetriesAfterUnauthorized() async throws {
        let store = InMemoryTokenStore(token: "refresh-1")
        let client = ModelServerClient(
            baseURL: URL(string: "https://example.test")!,
            session: stubbedSession(),
            tokenStore: store
        )

        var refreshCount = 0
        var projectCount = 0
        URLProtocolStub.handler = { request in
            if request.url?.path == "/api/v1/auth/refresh" {
                refreshCount += 1
                return jsonResponse([
                    "access_token": "access-\(refreshCount)",
                    "refresh_token": "refresh-\(refreshCount + 1)"
                ], status: 200)
            }

            projectCount += 1
            if projectCount == 1 {
                return jsonResponse(["error": "expired"], status: 401)
            }
            try expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access-2", "retry should use new token")
            return jsonResponse([
                "data": [
                    "id": "p1",
                    "name": "Project X"
                ]
            ], status: 200)
        }

        let project = try await client.fetchProject(id: "p1")

        try expect(project.id == "p1", "retry should decode project")
        try expect(refreshCount == 2, "client should refresh before initial request and after 401")
        try expect(projectCount == 2, "client should retry exactly once")
    }

    private static func testRefreshFailureClearsToken() async throws {
        let store = InMemoryTokenStore(token: "refresh-1")
        let client = ModelServerClient(
            baseURL: URL(string: "https://example.test")!,
            session: stubbedSession(),
            tokenStore: store
        )

        URLProtocolStub.handler = { _ in
            jsonResponse(["error": "bad token"], status: 401)
        }

        do {
            _ = try await client.fetchProject(id: "p1")
            throw TestFailure("expected request to throw")
        } catch {
            let savedRefreshToken = try store.loadRefreshToken()
            try expect(savedRefreshToken == nil, "refresh failure should clear token")
        }
    }

    private static func testNetworkRefreshFailurePreservesToken() async throws {
        let store = InMemoryTokenStore(token: "refresh-1")
        let client = ModelServerClient(
            baseURL: URL(string: "https://example.test")!,
            session: stubbedSession(),
            tokenStore: store
        )

        URLProtocolStub.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await client.fetchProject(id: "p1")
            throw TestFailure("expected network failure")
        } catch {
            let savedRefreshToken = try store.loadRefreshToken()
            try expect(savedRefreshToken == "refresh-1", "network failure should preserve refresh token")
        }
    }

    private static func testSessionLoginDoesNotSaveKeychainToken() async throws {
        let store = InMemoryTokenStore()
        let client = ModelServerClient(
            baseURL: URL(string: "https://example.test")!,
            session: stubbedSession(),
            tokenStore: store
        )

        var projectAuthorization: String?
        URLProtocolStub.handler = { request in
            if request.url?.path == "/api/v1/auth/oauth/oidc" {
                return jsonResponse([
                    "access_token": "access-session",
                    "refresh_token": "refresh-session"
                ], status: 200)
            }

            projectAuthorization = request.value(forHTTPHeaderField: "Authorization")
            return jsonResponse([
                "data": [
                    "id": "p1",
                    "name": "Project X"
                ]
            ], status: 200)
        }

        try await client.exchange(
            callback: OAuthCallback(provider: "oidc", code: "code-1", state: nil),
            persistRefreshToken: false
        )
        let project = try await client.fetchProject(id: "p1")
        let savedRefreshToken = try store.loadRefreshToken()

        try expect(project.name == "Project X", "session login should authenticate current run")
        try expect(projectAuthorization == "Bearer access-session", "session access token should be used")
        try expect(savedRefreshToken == nil, "session login should not save refresh token")
    }

    private static func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private static func jsonResponse(_ object: Any, status: Int) -> (HTTPURLResponse, Data) {
        let data = try! JSONSerialization.data(withJSONObject: object)
        let response = HTTPURLResponse(
            url: URL(string: "https://example.test")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, data)
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw TestFailure(message)
        }
    }

}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

private struct TestRunner {
    private var failures: [String] = []

    mutating func run(_ name: String, body: () async throws -> Void) async {
        do {
            try await body()
            print("PASS \(name)")
        } catch {
            failures.append("\(name): \(error)")
            print("FAIL \(name): \(error)")
        }
    }

    func finish() -> Never {
        if failures.isEmpty {
            print("All self-tests passed")
            Foundation.exit(0)
        }
        print("\(failures.count) self-test(s) failed")
        for failure in failures {
            print("- \(failure)")
        }
        Foundation.exit(1)
    }
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    static let lock = NSLock()
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
