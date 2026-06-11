import AppKit
import Foundation
import SwiftUI
import StatusBoardCore

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var state = DashboardState()
    @Published var isLoading = false
    @Published var isAuthenticated = false
    @Published var callbackURL = ""
    @Published var loginMessage: String?
    @Published var isClearingCredentials = false
    @Published var rememberLogin = false

    var loginWindowFactory: ((DashboardViewModel) -> Void)?
    var clearLoginSession: (() async -> Void)?

    private let client: ModelServerClient
    private let service: DashboardService
    private let configuration: AppConfiguration
    private var timer: Timer?

    init(client: ModelServerClient, service: DashboardService, configuration: AppConfiguration) {
        self.client = client
        self.service = service
        self.configuration = configuration
        self.isAuthenticated = client.hasSavedRefreshToken()
        self.rememberLogin = client.hasSavedRefreshToken()
        if let lastProjectName = configuration.lastProjectName {
            state.projectName = lastProjectName
        }
    }

    func start() {
        Task {
            await refresh()
        }
        timer = Timer.scheduledTimer(withTimeInterval: configuration.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        guard await client.canAuthenticate() else {
            isAuthenticated = false
            state.error = nil
            return
        }

        isAuthenticated = true
        isLoading = true
        defer { isLoading = false }

        do {
            state = try await service.loadDashboard()
            loginMessage = nil
        } catch {
            var existing = state
            existing.error = error.localizedDescription
            existing.lastUpdated = state.lastUpdated
            state = existing
            if (error as? ModelServerClientError) == .unauthenticated {
                isAuthenticated = false
            }
        }
    }

    func openLogin() {
        loginWindowFactory?(self)
    }

    func completeLogin() async {
        await completeLogin(with: callbackURL)
    }

    func completeLogin(with rawURL: String) async {
        do {
            let callback = try AuthCallbackParser.parse(rawURL)
            try await client.exchange(callback: callback, persistRefreshToken: rememberLogin)
            callbackURL = ""
            isAuthenticated = true
            loginMessage = rememberLogin ? "登录成功，已保存到钥匙串" : "登录成功，本次运行有效"
            await refresh()
        } catch {
            loginMessage = error.localizedDescription
        }
    }

    func clearCredentials() {
        Task {
            do {
                isClearingCredentials = true
                try await client.signOut()
                await clearLoginSession?()
                isAuthenticated = false
                loginMessage = "已清除本地凭证"
                rememberLogin = false
            } catch {
                loginMessage = error.localizedDescription
            }
            isClearingCredentials = false
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }
}
