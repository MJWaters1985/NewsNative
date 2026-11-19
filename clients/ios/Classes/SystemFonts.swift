import SwiftUI
import UIKit

/// SystemFonts.swift: SwiftUI system fonts that grow with Dynamic Type the way `Font.custom(_:size:relativeTo:)` does,
/// for the story list views that used NewsBlur's bundled Whitney font.
extension Font {
    static func nbSystem(size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let scaled = UIFontMetrics(forTextStyle: style.uiTextStyle).scaledValue(for: size)
        return .system(size: scaled, weight: weight)
    }
}

private extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        default: return .body
        }
    }
}
