import SwiftUI
import StatusBoardCore

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 460, height: 640)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.state.projectName)
                    .font(.headline)
                Text(viewModel.state.period)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: viewModel.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("刷新")
        }
        .padding(16)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isAuthenticated {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let error = viewModel.state.error {
                        MessageBox(text: error, style: .warning)
                    }
                    MetricGrid(totals: viewModel.state.totals, costs: viewModel.state.costs)
                    QuotaSection(windows: viewModel.state.quotaWindows)
                    DailyUsageChart(points: viewModel.state.dailyUsage)
                    ModelUsageSection(rows: viewModel.state.modelUsage)
                    RecentRequestsSection(rows: viewModel.state.recentRequests)
                }
                .padding(16)
            }
        } else {
            LoginView(viewModel: viewModel)
                .padding(16)
        }
    }

    private var footer: some View {
        HStack {
            if viewModel.isAuthenticated {
                Text("更新：\(DateFormatting.localDateTime(viewModel.state.lastUpdated))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if viewModel.isClearingCredentials {
                Text("正在清理凭证...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if viewModel.isAuthenticated {
                Button(viewModel.isClearingCredentials ? "清理中..." : "退出登录") {
                    viewModel.clearCredentials()
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isClearingCredentials)
            }
            Button("退出") {
                viewModel.quit()
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct LoginView: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack {
            Spacer(minLength: 28)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("登录 ModelServer")
                            .font(.title3.weight(.semibold))
                        Text("授权完成后自动回到看板。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    viewModel.openLogin()
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.forward.app")
                        Text("登录")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isClearingCredentials)

                Toggle(isOn: $viewModel.rememberLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("记住登录")
                            .font(.callout.weight(.medium))
                        Text("下次启动自动使用已保存凭据。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                .disabled(viewModel.isClearingCredentials)

                if let message = viewModel.loginMessage {
                    LoginMessage(text: message)
                }

                Divider()

                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("https://code.cs.ac.cn/auth/callback/oidc?code=...", text: $viewModel.callbackURL)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            Task { await viewModel.completeLogin() }
                        } label: {
                            Label("提交回调 URL", systemImage: "checkmark.circle")
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(viewModel.callbackURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.top, 8)
                } label: {
                    Text("手动回调")
                        .font(.caption.weight(.medium))
                }
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

            Spacer(minLength: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LoginMessage: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MetricGrid: View {
    let totals: DashboardTotals
    let costs: DashboardCosts?

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                MetricTile(title: "请求", value: totals.requests.formatted, icon: "bolt.horizontal")
                MetricTile(title: "Tokens", value: totals.tokens.formatted, icon: "number")
                MetricTile(title: "Credits", value: totals.creditsK.formatted, icon: "creditcard")
                MetricTile(title: "日均请求", value: totals.averageDailyRequests.formatted, icon: "clock")
            }

            if let costs {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    MetricTile(title: "标准价", value: costs.apiStandardPrice.formatted, icon: "yensign.circle")
                    MetricTile(title: "已支付", value: costs.periodPaid.formatted, icon: "wallet.pass")
                    MetricTile(
                        title: "节省",
                        value: costs.savedByPlan.formatted,
                        subtitle: costs.savedPercent.map { "约 \(Int($0.rounded()))%" },
                        icon: "arrow.down.circle"
                    )
                }
                Text(costs.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    var subtitle: String?
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct QuotaSection: View {
    let windows: [QuotaWindow]

    var body: some View {
        SectionBox(title: "额度用量") {
            if windows.isEmpty {
                Text("暂无额度窗口数据")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(windows) { window in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                QuotaWindowBadge(label: window.label)
                                Spacer()
                                Text("已用 \(UsageMetric(window.usedPercent, kind: .percentage).formatted)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !window.resetText.isEmpty {
                                    Text("· \(window.resetText)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            ProgressView(value: min(window.usedPercent, 100), total: 100)
                                .tint(window.usedPercent > 80 ? .orange : .accentColor)
                        }
                    }
                }
            }
        }
    }
}

private struct QuotaWindowBadge: View {
    let label: String

    var body: some View {
        Label {
            Text(label)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        } icon: {
            Image(systemName: label.lowercased().contains("h") ? "timer" : "calendar")
                .font(.caption2)
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct DailyUsageChart: View {
    let points: [DailyUsagePoint]

    var body: some View {
        SectionBox(title: "日趋势") {
            if points.isEmpty {
                Text("暂无日趋势数据")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                GeometryReader { proxy in
                    let maxRequests = max(points.map(\.requestCount).max() ?? 1, 1)
                    Path { path in
                        for index in points.indices {
                            let x = proxy.size.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
                            let yRatio = CGFloat(points[index].requestCount) / CGFloat(maxRequests)
                            let y = proxy.size.height - proxy.size.height * yRatio
                            if index == points.startIndex {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                .frame(height: 96)
            }
        }
    }
}

private struct ModelUsageSection: View {
    let rows: [ModelUsageRow]

    var body: some View {
        SectionBox(title: "模型排行") {
            VStack(spacing: 8) {
                ForEach(rows.prefix(8)) { row in
                    HStack {
                        Text(row.model)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(row.creditsK.formatted)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(row.requests.formatted)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 54, alignment: .trailing)
                    }
                }
                if rows.isEmpty {
                    Text("暂无模型用量")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct RecentRequestsSection: View {
    let rows: [RecentRequestRow]

    var body: some View {
        SectionBox(title: "近期请求") {
            VStack(spacing: 8) {
                ForEach(rows) { row in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.model)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Text(DateFormatting.localDateTime(row.createdAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(row.status)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                        Text(row.tokens.formatted)
                            .font(.caption.monospacedDigit())
                            .frame(width: 48, alignment: .trailing)
                        Text(row.latency.formatted)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 64, alignment: .trailing)
                    }
                }
                if rows.isEmpty {
                    Text("暂无近期请求")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct SectionBox<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MessageBox: View {
    enum Style {
        case warning
    }

    let text: String
    let style: Style

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.orange)
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
