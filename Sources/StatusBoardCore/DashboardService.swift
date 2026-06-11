import Foundation

public actor DashboardService {
    private let client: ModelServerClient
    private let configuration: AppConfiguration

    public init(client: ModelServerClient, configuration: AppConfiguration) {
        self.client = client
        self.configuration = configuration
    }

    public func loadDashboard(now: Date = Date()) async throws -> DashboardState {
        let project = try await selectProject()
        async let overview = client.fetchUsageOverview(projectId: project.id)
        async let daily = client.fetchDailyUsage(projectId: project.id)
        async let models = client.fetchModelUsage(projectId: project.id)
        async let requests = client.fetchRecentRequests(projectId: project.id)
        async let quota = optionalQuota(projectId: project.id)
        async let subscription = optionalSubscriptionUsage(projectId: project.id)

        return try await DashboardNormalizer.makeState(
            project: project,
            overview: overview,
            dailyUsage: daily,
            modelUsage: models,
            recentRequests: requests,
            quota: quota,
            subscriptionUsage: subscription,
            now: now
        )
    }

    private func selectProject() async throws -> Project {
        if let configuredProjectId = configuration.projectId {
            let project = try await client.fetchProject(id: configuredProjectId)
            configuration.lastProjectName = project.name
            return project
        }

        let projects = try await client.fetchProjects()
        guard let project = projects.first else {
            throw ModelServerClientError.httpStatus(404, "No projects available")
        }
        configuration.projectId = project.id
        configuration.lastProjectName = project.name
        return project
    }

    private func optionalQuota(projectId: String) async -> QuotaDTO? {
        try? await client.fetchQuota(projectId: projectId)
    }

    private func optionalSubscriptionUsage(projectId: String) async -> [QuotaWindowDTO] {
        (try? await client.fetchSubscriptionUsage(projectId: projectId)) ?? []
    }
}
