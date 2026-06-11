import Foundation

public struct APIEnvelope<T: Decodable>: Decodable {
    public let data: T
    public let meta: APIMeta?
}

public struct APIMeta: Decodable, Equatable, Sendable {
    public let page: Int?
    public let perPage: Int?
    public let total: Int?
    public let totalPages: Int?

    enum CodingKeys: String, CodingKey {
        case page
        case perPage = "per_page"
        case total
        case totalPages = "total_pages"
    }
}

public struct Project: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String?

    public init(id: String, name: String, description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }
}

public struct UsageOverviewDTO: Decodable, Equatable, Sendable {
    public let requestCount: Int?
    public let totalTokens: Double?
    public let totalCreditsK: Double?
    public let periodSource: String?
    public let costBreakdown: CostBreakdownDTO?

    public init(
        requestCount: Int? = nil,
        totalTokens: Double? = nil,
        totalCreditsK: Double? = nil,
        periodSource: String? = nil,
        costBreakdown: CostBreakdownDTO? = nil
    ) {
        self.requestCount = requestCount
        self.totalTokens = totalTokens
        self.totalCreditsK = totalCreditsK
        self.periodSource = periodSource
        self.costBreakdown = costBreakdown
    }

    enum CodingKeys: String, CodingKey {
        case requestCount = "request_count"
        case totalTokens = "total_tokens"
        case totalCreditsK = "total_credits_k"
        case periodSource = "period_source"
        case costBreakdown = "cost_breakdown"
    }
}

public struct CostBreakdownDTO: Decodable, Equatable, Sendable {
    public let apiStandardFen: Double?
    public let actualPaidFen: Double?
    public let subscriptionFen: Double?
    public let extraUsageFen: Double?
    public let savedFen: Double?
    public let hasActiveSubscription: Bool?
    public let periodStart: String?
    public let periodEnd: String?

    public init(
        apiStandardFen: Double? = nil,
        actualPaidFen: Double? = nil,
        subscriptionFen: Double? = nil,
        extraUsageFen: Double? = nil,
        savedFen: Double? = nil,
        hasActiveSubscription: Bool? = nil,
        periodStart: String? = nil,
        periodEnd: String? = nil
    ) {
        self.apiStandardFen = apiStandardFen
        self.actualPaidFen = actualPaidFen
        self.subscriptionFen = subscriptionFen
        self.extraUsageFen = extraUsageFen
        self.savedFen = savedFen
        self.hasActiveSubscription = hasActiveSubscription
        self.periodStart = periodStart
        self.periodEnd = periodEnd
    }

    enum CodingKeys: String, CodingKey {
        case apiStandardFen = "api_standard_fen"
        case actualPaidFen = "actual_paid_fen"
        case subscriptionFen = "subscription_fen"
        case extraUsageFen = "extra_usage_fen"
        case savedFen = "saved_fen"
        case hasActiveSubscription = "has_active_subscription"
        case periodStart = "period_start"
        case periodEnd = "period_end"
    }
}

public struct UsageBucketDTO: Decodable, Equatable, Sendable {
    public let date: String?
    public let model: String?
    public let requestCount: Int?
    public let totalTokens: Double?
    public let totalCreditsK: Double?
    public let totalInputTokens: Double?
    public let totalOutputTokens: Double?
    public let averageLatencyMS: Double?

    public init(
        date: String? = nil,
        model: String? = nil,
        requestCount: Int? = nil,
        totalTokens: Double? = nil,
        totalCreditsK: Double? = nil,
        totalInputTokens: Double? = nil,
        totalOutputTokens: Double? = nil,
        averageLatencyMS: Double? = nil
    ) {
        self.date = date
        self.model = model
        self.requestCount = requestCount
        self.totalTokens = totalTokens
        self.totalCreditsK = totalCreditsK
        self.totalInputTokens = totalInputTokens
        self.totalOutputTokens = totalOutputTokens
        self.averageLatencyMS = averageLatencyMS
    }

    enum CodingKeys: String, CodingKey {
        case date
        case model
        case requestCount = "request_count"
        case totalTokens = "total_tokens"
        case totalCreditsK = "total_credits_k"
        case totalInputTokens = "total_input_tokens"
        case totalOutputTokens = "total_output_tokens"
        case averageLatencyMS = "avg_latency_ms"
    }
}

public struct RecentRequestDTO: Decodable, Equatable, Sendable {
    public let id: String?
    public let model: String?
    public let status: String?
    public let inputTokens: Double?
    public let outputTokens: Double?
    public let latencyMS: Double?
    public let createdAt: String?

    public init(
        id: String? = nil,
        model: String? = nil,
        status: String? = nil,
        inputTokens: Double? = nil,
        outputTokens: Double? = nil,
        latencyMS: Double? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.model = model
        self.status = status
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.latencyMS = latencyMS
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case model
        case status
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case latencyMS = "latency_ms"
        case createdAt = "created_at"
    }
}

public struct QuotaDTO: Decodable, Equatable, Sendable {
    public let creditQuotaPercent: Double?
    public let windows: [QuotaWindowDTO]?

    public init(creditQuotaPercent: Double? = nil, windows: [QuotaWindowDTO]? = nil) {
        self.creditQuotaPercent = creditQuotaPercent
        self.windows = windows
    }

    enum CodingKeys: String, CodingKey {
        case creditQuotaPercent = "credit_quota_percent"
        case windows
    }
}

public struct QuotaWindowDTO: Decodable, Equatable, Sendable {
    public let window: String?
    public let percentage: Double?
    public let utilization: Double?
    public let resetsAt: String?

    public init(
        window: String? = nil,
        percentage: Double? = nil,
        utilization: Double? = nil,
        resetsAt: String? = nil
    ) {
        self.window = window
        self.percentage = percentage
        self.utilization = utilization
        self.resetsAt = resetsAt
    }

    enum CodingKeys: String, CodingKey {
        case window
        case percentage
        case utilization
        case resetsAt = "resets_at"
    }
}

public struct AuthResponse: Decodable, Equatable, Sendable {
    public let accessToken: String?
    public let refreshToken: String?
    public let redirectTo: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case redirectTo = "redirect_to"
    }
}
