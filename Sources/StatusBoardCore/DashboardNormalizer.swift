import Foundation

public enum DashboardNormalizer {
    public static func makeState(
        project: Project,
        overview: UsageOverviewDTO,
        dailyUsage: [UsageBucketDTO],
        modelUsage: [UsageBucketDTO],
        recentRequests: [RecentRequestDTO],
        quota: QuotaDTO?,
        subscriptionUsage: [QuotaWindowDTO],
        now: Date = Date()
    ) -> DashboardState {
        let daily = dailyUsage.map {
            DailyUsagePoint(
                date: $0.date ?? "",
                requestCount: max(0, $0.requestCount ?? 0),
                creditsK: max(0, $0.totalCreditsK ?? 0)
            )
        }

        let modelRows = modelUsage
            .map { bucket in
                ModelUsageRow(
                    model: bucket.model ?? "unknown",
                    creditsK: UsageMetric(bucket.totalCreditsK ?? 0, kind: .creditsK),
                    requests: UsageMetric(Double(bucket.requestCount ?? 0), kind: .requests),
                    inputTokens: UsageMetric(bucket.totalInputTokens ?? 0, kind: .tokens),
                    outputTokens: UsageMetric(bucket.totalOutputTokens ?? 0, kind: .tokens),
                    averageLatency: UsageMetric(bucket.averageLatencyMS ?? 0, kind: .latencyMilliseconds)
                )
            }
            .sorted { $0.creditsK.rawValue > $1.creditsK.rawValue }

        let requestRows = recentRequests.map { request in
            RecentRequestRow(
                id: request.id ?? UUID().uuidString,
                model: request.model ?? "unknown",
                status: request.status ?? "unknown",
                tokens: UsageMetric((request.inputTokens ?? 0) + (request.outputTokens ?? 0), kind: .tokens),
                latency: UsageMetric(request.latencyMS ?? 0, kind: .latencyMilliseconds),
                createdAt: DateFormatting.parse(request.createdAt)
            )
        }

        let cost = overview.costBreakdown.map(normalizeCost)
        let quotaWindows = normalizeQuotaWindows(
            quota: quota,
            subscriptionUsage: subscriptionUsage,
            now: now
        )

        return DashboardState(
            projectId: project.id,
            projectName: project.name,
            period: normalizePeriod(overview: overview),
            totals: DashboardTotals(
                requests: UsageMetric(Double(overview.requestCount ?? 0), kind: .requests),
                tokens: UsageMetric(overview.totalTokens ?? 0, kind: .tokens),
                creditsK: UsageMetric(overview.totalCreditsK ?? 0, kind: .creditsK),
                averageDailyRequests: UsageMetric(averageDailyRequests(from: daily), kind: .requests)
            ),
            costs: cost,
            quotaWindows: quotaWindows,
            dailyUsage: daily,
            modelUsage: modelRows,
            recentRequests: requestRows,
            lastUpdated: now,
            error: nil
        )
    }

    public static func normalizeQuotaWindows(
        quota: QuotaDTO?,
        subscriptionUsage: [QuotaWindowDTO],
        now: Date = Date()
    ) -> [QuotaWindow] {
        let source = subscriptionUsage.isEmpty ? (quota?.windows ?? []) : subscriptionUsage
        return source.map { item in
            QuotaWindow(
                label: item.window ?? "quota",
                usedPercent: item.percentage ?? item.utilization ?? 0,
                resetAt: DateFormatting.parse(item.resetsAt),
                now: now
            )
        }
    }

    private static func normalizeCost(_ cost: CostBreakdownDTO) -> DashboardCosts {
        let apiStandard = cost.apiStandardFen ?? 0
        let actualPaid = cost.actualPaidFen ?? 0
        let saved = cost.savedFen ?? max(0, apiStandard - actualPaid)
        let savedPercent = apiStandard > 0 ? saved / apiStandard * 100 : nil
        let detail = (cost.hasActiveSubscription ?? false)
            ? "订阅 \(UsageMetric(cost.subscriptionFen ?? 0, kind: .currencyFen).formatted) + 额外 \(UsageMetric(cost.extraUsageFen ?? 0, kind: .currencyFen).formatted)"
            : "额外用量 \(UsageMetric(cost.extraUsageFen ?? 0, kind: .currencyFen).formatted)"

        return DashboardCosts(
            apiStandardPrice: UsageMetric(apiStandard, kind: .currencyFen),
            periodPaid: UsageMetric(actualPaid, kind: .currencyFen),
            savedByPlan: UsageMetric(saved, kind: .currencyFen),
            savedPercent: savedPercent,
            detail: detail
        )
    }

    private static func normalizePeriod(overview: UsageOverviewDTO) -> String {
        guard overview.periodSource == "subscription",
              let cost = overview.costBreakdown,
              let start = DateFormatting.parse(cost.periodStart),
              let end = DateFormatting.parse(cost.periodEnd) else {
            return "最近 30 天"
        }
        return "\(DateFormatting.shortDate(start)) - \(DateFormatting.shortDate(end))"
    }

    private static func averageDailyRequests(from dailyUsage: [DailyUsagePoint]) -> Double {
        guard !dailyUsage.isEmpty else {
            return 0
        }
        let total = dailyUsage.reduce(0) { $0 + $1.requestCount }
        return Double(total) / Double(dailyUsage.count)
    }
}
