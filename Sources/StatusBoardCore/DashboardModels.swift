import Foundation

public struct DashboardState: Equatable, Sendable {
    public var projectId: String?
    public var projectName: String
    public var period: String
    public var totals: DashboardTotals
    public var costs: DashboardCosts?
    public var quotaWindows: [QuotaWindow]
    public var dailyUsage: [DailyUsagePoint]
    public var modelUsage: [ModelUsageRow]
    public var recentRequests: [RecentRequestRow]
    public var lastUpdated: Date?
    public var error: String?

    public init(
        projectId: String? = nil,
        projectName: String = "ModelServer",
        period: String = "未加载",
        totals: DashboardTotals = DashboardTotals(),
        costs: DashboardCosts? = nil,
        quotaWindows: [QuotaWindow] = [],
        dailyUsage: [DailyUsagePoint] = [],
        modelUsage: [ModelUsageRow] = [],
        recentRequests: [RecentRequestRow] = [],
        lastUpdated: Date? = nil,
        error: String? = nil
    ) {
        self.projectId = projectId
        self.projectName = projectName
        self.period = period
        self.totals = totals
        self.costs = costs
        self.quotaWindows = quotaWindows
        self.dailyUsage = dailyUsage
        self.modelUsage = modelUsage
        self.recentRequests = recentRequests
        self.lastUpdated = lastUpdated
        self.error = error
    }

    public var statusTitle: String {
        let title = quotaWindows
            .filter { !$0.label.isEmpty }
            .prefix(2)
            .map { "\($0.label) 已用 \(Int($0.usedPercent.rounded()))%" }
            .joined(separator: " · ")
        return title.isEmpty ? "MS" : title
    }
}

public struct DashboardTotals: Equatable, Sendable {
    public var requests: UsageMetric
    public var tokens: UsageMetric
    public var creditsK: UsageMetric
    public var averageDailyRequests: UsageMetric

    public init(
        requests: UsageMetric = UsageMetric(0, kind: .requests),
        tokens: UsageMetric = UsageMetric(0, kind: .tokens),
        creditsK: UsageMetric = UsageMetric(0, kind: .creditsK),
        averageDailyRequests: UsageMetric = UsageMetric(0, kind: .requests)
    ) {
        self.requests = requests
        self.tokens = tokens
        self.creditsK = creditsK
        self.averageDailyRequests = averageDailyRequests
    }
}

public struct DashboardCosts: Equatable, Sendable {
    public var apiStandardPrice: UsageMetric
    public var periodPaid: UsageMetric
    public var savedByPlan: UsageMetric
    public var savedPercent: Double?
    public var detail: String

    public init(
        apiStandardPrice: UsageMetric,
        periodPaid: UsageMetric,
        savedByPlan: UsageMetric,
        savedPercent: Double?,
        detail: String
    ) {
        self.apiStandardPrice = apiStandardPrice
        self.periodPaid = periodPaid
        self.savedByPlan = savedByPlan
        self.savedPercent = savedPercent
        self.detail = detail
    }
}

public struct QuotaWindow: Equatable, Identifiable, Sendable {
    public var id: String { label }
    public var label: String
    public var usedPercent: Double
    public var remainingPercent: Double
    public var resetAt: Date?
    public var resetText: String

    public init(label: String, usedPercent: Double, resetAt: Date?, now: Date = Date()) {
        self.label = label
        self.usedPercent = max(0, usedPercent)
        self.remainingPercent = max(0, 100 - max(0, usedPercent))
        self.resetAt = resetAt
        self.resetText = DateFormatting.relativeResetText(resetAt: resetAt, now: now)
    }
}

public struct DailyUsagePoint: Equatable, Identifiable, Sendable {
    public var id: String { date }
    public var date: String
    public var requestCount: Int
    public var creditsK: Double

    public init(date: String, requestCount: Int, creditsK: Double) {
        self.date = date
        self.requestCount = requestCount
        self.creditsK = creditsK
    }
}

public struct ModelUsageRow: Equatable, Identifiable, Sendable {
    public var id: String { model }
    public var model: String
    public var creditsK: UsageMetric
    public var requests: UsageMetric
    public var inputTokens: UsageMetric
    public var outputTokens: UsageMetric
    public var averageLatency: UsageMetric

    public init(
        model: String,
        creditsK: UsageMetric,
        requests: UsageMetric,
        inputTokens: UsageMetric,
        outputTokens: UsageMetric,
        averageLatency: UsageMetric
    ) {
        self.model = model
        self.creditsK = creditsK
        self.requests = requests
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.averageLatency = averageLatency
    }
}

public struct RecentRequestRow: Equatable, Identifiable, Sendable {
    public var id: String
    public var model: String
    public var status: String
    public var tokens: UsageMetric
    public var latency: UsageMetric
    public var createdAt: Date?

    public init(
        id: String,
        model: String,
        status: String,
        tokens: UsageMetric,
        latency: UsageMetric,
        createdAt: Date?
    ) {
        self.id = id
        self.model = model
        self.status = status
        self.tokens = tokens
        self.latency = latency
        self.createdAt = createdAt
    }
}
