// 撤销条：放在单独的透明窗口里，面板打开时也能显示在最上层。
import SwiftUI
import UIKit

@MainActor @Observable final class ToastCenter {
    static let shared = ToastCenter()

    struct Item: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let hasUndo: Bool
    }

    private(set) var item: Item?
    /// 有面板打开时显示在顶部，否则在底部
    var atTop = false
    var colorScheme: ColorScheme = .light
    @ObservationIgnored private var undo: (() -> Void)?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var window: UIWindow?
    /// 撤销条在窗口中的位置；窗口其余区域把触摸让给下面的 App。
    @ObservationIgnored var toastFrame: CGRect = .null

    func show(_ text: String, undo: (() -> Void)? = nil, seconds: Double = 3) {
        install()
        self.undo = undo
        item = Item(text: text, hasUndo: undo != nil)
        AccessibilityNotification.Announcement(text).post()
        task?.cancel()
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func performUndo() {
        let u = undo
        dismiss()
        u?()
    }

    func dismiss() {
        task?.cancel()
        undo = nil
        item = nil
        toastFrame = .null
    }

    private func install() {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        let w = PassthroughWindow(windowScene: scene)
        w.toastCenter = self
        w.windowLevel = .alert + 1
        let host = UIHostingController(rootView: ToastOverlay(center: self))
        host.view.backgroundColor = .clear
        w.rootViewController = host
        w.isHidden = false
        window = w
    }
}

private final class PassthroughWindow: UIWindow {
    weak var toastCenter: ToastCenter?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let toastCenter, toastCenter.item != nil, toastCenter.toastFrame.contains(point) else { return nil }
        return super.hitTest(point, with: event)
    }
}

private struct ToastOverlay: View {
    let center: ToastCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            if center.atTop { toast.padding(.top, 64) }
            Spacer(minLength: 0)
            if !center.atTop { toast.padding(.bottom, 96) }
        }
        .padding(.horizontal, Theme.gutter)
        .environment(\.colorScheme, center.colorScheme)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .snappy(duration: 0.25), value: center.item)
    }

    @ViewBuilder private var toast: some View {
        if let item = center.item {
            HStack(spacing: 12) {
                Text(item.text)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if item.hasUndo {
                    Button("撤销") { center.performUndo() }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .frame(minHeight: 36)
                        .accessibilityIdentifier("toast-undo")
                }
            }
            .foregroundStyle(Theme.toastFg)
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .frame(minHeight: 46)
            .background(Theme.toastBg, in: Capsule())
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { center.toastFrame = $0 }
            .id(item.id)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: center.atTop ? .top : .bottom)))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("toast")
        }
    }
}
