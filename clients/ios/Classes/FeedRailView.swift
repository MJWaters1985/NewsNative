import UIKit

/// FeedRailView.swift: the feed list's Add, intelligence filter and Settings controls, stacked for the side rail of an
/// open iPhone Duo. UIKit gives an expanded split view's rail only its own sidebar button, so FeedsObjCViewController.m
/// places this view in the rail, matching the native vertical toolbar of the closed Duo, and hides the bottom toolbar.
@objcMembers final class FeedRailView: UIView {
    /// The width of each control, matching the closed Duo's native rail buttons.
    static let controlWidth: CGFloat = 48
    /// The gap between the screen's bottom edge and the Settings button, matching the closed Duo's native rail.
    static let bottomMargin: CGFloat = 24
    /// The distance from the screen edge to the centre of the native rail buttons, which UIKit sets inside the inset.
    static let edgeCenterDistance: CGFloat = 48.5
    private static let groupSpacing: CGFloat = 12
    private static let filterInset: CGFloat = 4

    let addButton = UIButton(type: .system)
    let settingsButton = UIButton(type: .system)
    private(set) var filterButtons: [UIButton] = []

    var onAdd: (() -> Void)?
    var onSettings: (() -> Void)?
    var onSelectFilter: ((Int) -> Void)?

    /// The selected intelligence filter: 0 All, 1 Unread, 2 Focus, 3 Saved.
    var selectedIndex: Int = 0 {
        didSet {
            guard selectedIndex != oldValue else { return }
            updateSelection()
            setNeedsLayout()
        }
    }

    private let addBackground = FeedRailView.makeBackground()
    private let filterBackground = FeedRailView.makeBackground()
    private let settingsBackground = FeedRailView.makeBackground()
    private let selectionView = UIView()

    /// The size the rail needs: Add, the filters in one capsule, then Settings.
    var fittingSize: CGSize {
        CGSize(width: FeedRailView.controlWidth,
               height: FeedRailView.controlWidth * 2 + filterCapsuleHeight + FeedRailView.groupSpacing * 2)
    }

    private var filterCapsuleHeight: CGFloat {
        (FeedRailView.controlWidth - FeedRailView.filterInset * 2) * CGFloat(filterButtons.count) + FeedRailView.filterInset * 2
    }

    init(titles: [String], images: [UIImage], identifiers: [String]) {
        super.init(frame: .zero)
        accessibilityIdentifier = "feed-list-rail"

        for background in [addBackground, filterBackground, settingsBackground] {
            addSubview(background)
        }

        selectionView.isUserInteractionEnabled = false
        selectionView.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.28) : UIColor(white: 0, alpha: 0.12)
        }
        filterBackground.contentView.addSubview(selectionView)

        configure(addButton, image: UIImage(systemName: "plus"), title: NBLocalization.text("Add Site"),
                  identifier: "feed-list-add")
        addButton.addAction(UIAction { [weak self] _ in self?.onAdd?() }, for: .primaryActionTriggered)
        addBackground.contentView.addSubview(addButton)

        configure(settingsButton, image: UIImage(systemName: "gearshape"), title: NBLocalization.text("Settings"),
                  identifier: "feed-list-settings")
        settingsButton.addAction(UIAction { [weak self] _ in self?.onSettings?() }, for: .primaryActionTriggered)
        settingsBackground.contentView.addSubview(settingsButton)

        for index in titles.indices {
            let button = UIButton(type: .custom)
            configure(button, image: images[index], title: titles[index],
                      identifier: "feed-list-intelligence-" + identifiers[index])
            button.addAction(UIAction { [weak self] _ in self?.onSelectFilter?(index) }, for: .primaryActionTriggered)
            filterBackground.contentView.addSubview(button)
            filterButtons.append(button)
        }
        updateSelection()
        frame.size = fittingSize
    }

    required init?(coder: NSCoder) {
        fatalError("FeedRailView.swift is created in code only")
    }

    private static func makeBackground() -> UIVisualEffectView {
        let effect: UIVisualEffect
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect()
            glass.isInteractive = true
            effect = glass
        } else {
            effect = UIBlurEffect(style: .systemThinMaterial)
        }
        let view = UIVisualEffectView(effect: effect)
        view.clipsToBounds = true
        view.layer.cornerCurve = .continuous
        return view
    }

    private func configure(_ button: UIButton, image: UIImage?, title: String, identifier: String) {
        button.setImage(image, for: .normal)
        button.tintColor = .label
        button.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 19, weight: .medium),
                                               forImageIn: .normal)
        button.accessibilityLabel = title
        button.accessibilityIdentifier = identifier
        button.largeContentTitle = title
        button.showsLargeContentViewer = true
        button.addInteraction(UILargeContentViewerInteraction())
    }

    private func updateSelection() {
        for (index, button) in filterButtons.enumerated() {
            button.accessibilityTraits = index == selectedIndex ? [.button, .selected] : .button
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = FeedRailView.controlWidth
        let inset = FeedRailView.filterInset
        let spacing = FeedRailView.groupSpacing

        addBackground.frame = CGRect(x: 0, y: 0, width: width, height: width)
        filterBackground.frame = CGRect(x: 0, y: addBackground.frame.maxY + spacing,
                                        width: width, height: filterCapsuleHeight)
        settingsBackground.frame = CGRect(x: 0, y: filterBackground.frame.maxY + spacing, width: width, height: width)
        for background in [addBackground, filterBackground, settingsBackground] {
            background.layer.cornerRadius = width / 2
        }
        addButton.frame = addBackground.bounds
        settingsButton.frame = settingsBackground.bounds

        let filterSide = width - inset * 2
        for (index, button) in filterButtons.enumerated() {
            button.frame = CGRect(x: inset, y: inset + CGFloat(index) * filterSide, width: filterSide, height: filterSide)
        }
        if filterButtons.indices.contains(selectedIndex) {
            selectionView.frame = filterButtons[selectedIndex].frame
            selectionView.layer.cornerRadius = filterSide / 2
        }
    }
}
