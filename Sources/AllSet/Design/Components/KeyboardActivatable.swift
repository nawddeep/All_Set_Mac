import SwiftUI

/// A tile that's clicked to open, made usable without a pointer as well: it takes
/// keyboard focus, Return or Space activates it, Delete runs `delete` when there
/// is one, and VoiceOver gets the same as actions. For tiles that can't simply be
/// a Button (they hold buttons of their own, or a hover preview).
struct KeyboardActivatable: ViewModifier {
    let hint: String
    let activate: () -> Void
    var delete: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .focusable()
            .onKeyPress(keys: [.return, .space]) { _ in
                activate()
                return .handled
            }
            .onKeyPress(keys: [.delete, .deleteForward]) { _ in
                guard let delete else { return .ignored }
                delete()
                return .handled
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(hint)
            .accessibilityAction { activate() }
            .accessibilityActions {
                if let delete { Button("Delete…", action: delete) }
            }
    }
}

extension View {
    func keyboardActivatable(hint: String, activate: @escaping () -> Void, delete: (() -> Void)? = nil) -> some View {
        modifier(KeyboardActivatable(hint: hint, activate: activate, delete: delete))
    }
}
