import AppKit
import SwiftUI
import StatusBoardCore

@main
struct StatusBoardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let tokenStore = KeychainTokenStore()
        let configuration = AppConfiguration()
        let client = ModelServerClient(tokenStore: tokenStore)
        let service = DashboardService(client: client, configuration: configuration)
        let viewModel = DashboardViewModel(
            client: client,
            service: service,
            configuration: configuration
        )
        viewModel.loginWindowFactory = { viewModel in
            LoginWindowController.shared.show(viewModel: viewModel, authorizationURL: client.authorizationURL())
        }
        viewModel.clearLoginSession = {
            await LoginWindowController.shared.clearWebsiteSession()
        }

        statusBarController = StatusBarController(viewModel: viewModel)
        viewModel.start()
    }
}
