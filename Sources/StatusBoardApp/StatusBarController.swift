import AppKit
import Combine
import SwiftUI
import StatusBoardCore

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: DashboardViewModel) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 460, height: 640)
        popover.contentViewController = NSHostingController(rootView: DashboardView(viewModel: viewModel))

        if let button = statusItem.button {
            configure(button: button)
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        updateStatusBar(state: viewModel.state, isAuthenticated: viewModel.isAuthenticated)

        Publishers.CombineLatest(viewModel.$state, viewModel.$isAuthenticated)
            .receive(on: RunLoop.main)
            .sink { [weak self] state, isAuthenticated in
                self?.updateStatusBar(state: state, isAuthenticated: isAuthenticated)
            }
            .store(in: &cancellables)
    }

    private func configure(button: NSStatusBarButton) {
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
    }

    private func updateStatusBar(state: DashboardState, isAuthenticated: Bool) {
        guard let button = statusItem.button else {
            return
        }

        let windows = Array(state.quotaWindows.filter { !$0.label.isEmpty }.prefix(2))
        guard isAuthenticated, !windows.isEmpty else {
            statusItem.length = NSStatusItem.variableLength
            button.image = nil
            button.imagePosition = .noImage
            button.title = "MS"
            button.toolTip = "ModelServer"
            return
        }

        let image = StatusBarQuotaRenderer.image(for: windows, appearance: button.effectiveAppearance)
        statusItem.length = image.size.width + 8
        button.title = ""
        button.image = image
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.toolTip = StatusBarQuotaRenderer.tooltip(for: windows)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

private enum StatusBarQuotaRenderer {
    private static let itemHeight: CGFloat = 18
    private static let itemGap: CGFloat = 4
    private static let horizontalPadding: CGFloat = 6
    private static let barHeight: CGFloat = 3

    static func image(for windows: [QuotaWindow], appearance: NSAppearance) -> NSImage {
        let labelFont = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium)
        let items = windows.map { window in
            RenderItem(
                label: window.label,
                percentText: "\(Int(window.usedPercent.rounded()))%",
                progress: min(max(window.usedPercent, 0), 100) / 100
            )
        }
        let widths = items.map { item in
            let labelWidth = item.label.width(using: labelFont)
            let percentWidth = item.percentText.width(using: valueFont)
            return max(54, labelWidth + percentWidth + horizontalPadding * 2 + 8)
        }
        let totalWidth = widths.reduce(0, +) + itemGap * CGFloat(max(0, widths.count - 1))
        let image = NSImage(size: NSSize(width: ceil(totalWidth), height: itemHeight))
        image.isTemplate = false

        appearance.performAsCurrentDrawingAppearance {
            image.lockFocus()
            defer { image.unlockFocus() }

            let colors = Colors.current
            var x: CGFloat = 0

            for (index, item) in items.enumerated() {
                let width = widths[index]
                let rect = NSRect(x: x, y: 0, width: width, height: itemHeight)
                drawCapsule(item: item, rect: rect, labelFont: labelFont, valueFont: valueFont, colors: colors)
                x += width + itemGap
            }
        }

        return image
    }

    static func tooltip(for windows: [QuotaWindow]) -> String {
        windows
            .map { window in
                var text = "\(window.label)：已用 \(UsageMetric(window.usedPercent, kind: .percentage).formatted)"
                if !window.resetText.isEmpty {
                    text += "，\(window.resetText)"
                }
                return text
            }
            .joined(separator: "\n")
    }

    private static func drawCapsule(
        item: RenderItem,
        rect: NSRect,
        labelFont: NSFont,
        valueFont: NSFont,
        colors: Colors
    ) {
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5)
        colors.background.setFill()
        path.fill()
        colors.border.setStroke()
        path.lineWidth = 1
        path.stroke()

        let trackRect = NSRect(
            x: rect.minX + 4,
            y: rect.minY + 2,
            width: rect.width - 8,
            height: barHeight
        )
        NSBezierPath(roundedRect: trackRect, xRadius: barHeight / 2, yRadius: barHeight / 2).fill(with: colors.track)

        if item.progress > 0 {
            let fillWidth = max(barHeight, trackRect.width * item.progress)
            let fillRect = NSRect(x: trackRect.minX, y: trackRect.minY, width: fillWidth, height: trackRect.height)
            NSBezierPath(roundedRect: fillRect, xRadius: barHeight / 2, yRadius: barHeight / 2).fill(with: item.progress >= 0.8 ? colors.warning : colors.accent)
        }

        let baselineY: CGFloat = rect.minY + 6
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: colors.primary
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: colors.secondary
        ]
        let label = NSAttributedString(string: item.label, attributes: labelAttributes)
        let value = NSAttributedString(string: item.percentText, attributes: valueAttributes)

        label.draw(at: NSPoint(x: rect.minX + horizontalPadding, y: baselineY))
        value.draw(at: NSPoint(x: rect.maxX - horizontalPadding - value.size().width, y: baselineY))
    }

    private struct RenderItem {
        let label: String
        let percentText: String
        let progress: Double
    }

    private struct Colors {
        let primary: NSColor
        let secondary: NSColor
        let background: NSColor
        let border: NSColor
        let track: NSColor
        let accent: NSColor
        let warning: NSColor

        static var current: Colors {
            Colors(
                primary: .labelColor,
                secondary: .secondaryLabelColor,
                background: .controlBackgroundColor.withAlphaComponent(0.72),
                border: .separatorColor.withAlphaComponent(0.7),
                track: .tertiaryLabelColor.withAlphaComponent(0.22),
                accent: .controlAccentColor,
                warning: .systemOrange
            )
        }
    }
}

private extension String {
    func width(using font: NSFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return ceil((self as NSString).size(withAttributes: attributes).width)
    }
}

private extension NSBezierPath {
    func fill(with color: NSColor) {
        color.setFill()
        fill()
    }
}
