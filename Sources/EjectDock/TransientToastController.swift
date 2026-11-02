import AppKit

final class TransientToastController {
    enum Style {
        case success
        case failure
    }

    private var panel: NSPanel?
    private var dismissal: DispatchWorkItem?

    func dismiss() {
        precondition(Thread.isMainThread)
        dismissal?.cancel()
        dismissal = nil
        panel?.orderOut(nil)
        panel = nil
    }

    func show(message: String, style: Style, anchoredTo view: NSView, duration: TimeInterval = 4) {
        precondition(Thread.isMainThread)
        dismiss()

        let panel = makePanel(message: message, style: style)
        position(panel, anchoredTo: view)
        panel.orderFrontRegardless()
        self.panel = panel

        let dismissal = DispatchWorkItem { [weak self, weak panel] in
            panel?.orderOut(nil)
            if self?.panel === panel {
                self?.panel = nil
            }
        }
        self.dismissal = dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: dismissal)
    }

    private func makePanel(message: String, style: Style) -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.masksToBounds = true

        let symbolName = style == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        let imageView = NSImageView(image: NSImage(systemSymbolName: symbolName, accessibilityDescription: message) ?? NSImage())
        imageView.contentTintColor = style == .success ? .systemGreen : .systemOrange
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .semibold)

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 3
        label.preferredMaxLayoutWidth = 280

        let stack = NSStackView(views: [imageView, label])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 13, left: 14, bottom: 13, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            stack.topAnchor.constraint(equalTo: effect.topAnchor),
            stack.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 24),
            imageView.heightAnchor.constraint(equalToConstant: 24),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 280)
        ])

        effect.layoutSubtreeIfNeeded()
        let size = effect.fittingSize
        effect.frame = NSRect(origin: .zero, size: size)
        panel.contentView = effect
        panel.setContentSize(size)
        return panel
    }

    private func position(_ panel: NSPanel, anchoredTo view: NSView) {
        guard let window = view.window else { return }
        let anchor = window.convertToScreen(view.convert(view.bounds, to: nil))
        let screen = window.screen ?? NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? anchor
        let panelSize = panel.frame.size
        let centeredX = anchor.midX - panelSize.width / 2
        let x = min(max(centeredX, visibleFrame.minX + 8), visibleFrame.maxX - panelSize.width - 8)
        let preferredY = anchor.minY - panelSize.height - 8
        let y = max(preferredY, visibleFrame.minY + 8)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
