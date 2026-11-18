import SwiftUI

/// ThemeObserver.swift republishes SwiftUI views when the app theme changes, without redrawing them for unrelated
/// preference changes.
@available(iOS 15.0, *)
class ThemeObserver: ObservableObject {
    @Published var themeVersion: Int = 0

    private var observers: [NSObjectProtocol] = []
    private var effectiveTheme = ThemeManager.shared?.effectiveTheme ?? ThemeStyleLight

    init() {
        // ThemeObserver.swift preserves view identity when unrelated app preferences change.
        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let effectiveTheme = ThemeManager.shared?.effectiveTheme ?? ThemeStyleLight
            guard effectiveTheme != self.effectiveTheme else { return }
            self.effectiveTheme = effectiveTheme
            self.themeVersion += 1
        }
        observers.append(observer)
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
