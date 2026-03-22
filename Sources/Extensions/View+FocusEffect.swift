import SwiftUI

extension View {
    /// A backward-compatible modifier to disable the focus effect.
    /// Uses `.focusEffectDisabled()` on macOS 14.0 or newer, and falls back to a no-op otherwise.
    @ViewBuilder
    func disableFocusEffect() -> some View {
        if #available(macOS 14.0, *) {
            self.focusEffectDisabled()
        } else {
            self
        }
    }
}
