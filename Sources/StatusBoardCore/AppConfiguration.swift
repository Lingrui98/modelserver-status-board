import Foundation

public final class AppConfiguration: @unchecked Sendable {
    private enum Keys {
        static let projectId = "projectId"
        static let refreshInterval = "refreshInterval"
        static let lastProjectName = "lastProjectName"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var projectId: String? {
        get {
            let value = defaults.string(forKey: Keys.projectId)
            return value?.isEmpty == false ? value : nil
        }
        set {
            defaults.set(newValue, forKey: Keys.projectId)
        }
    }

    public var refreshInterval: TimeInterval {
        get {
            let value = defaults.double(forKey: Keys.refreshInterval)
            return value > 0 ? value : 60
        }
        set {
            defaults.set(max(10, newValue), forKey: Keys.refreshInterval)
        }
    }

    public var lastProjectName: String? {
        get {
            let value = defaults.string(forKey: Keys.lastProjectName)
            return value?.isEmpty == false ? value : nil
        }
        set {
            defaults.set(newValue, forKey: Keys.lastProjectName)
        }
    }
}
