//
//  FeedDetailViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-08-27.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit
import SwiftUI
import QuartzCore

@objcMembers final class BottomNextFeedControl: UIControl {
    private let capsuleView = UIView()
    private let arrowContainer = UIView()
    private let arrowImageView = UIImageView()
    private let targetIconView = UIImageView()
    private let titleLabel = UILabel()
    private var isReady = false
    private var didConfigureReadyState = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = true
        isAccessibilityElement = true
        accessibilityTraits = .button
        alpha = 0

        capsuleView.translatesAutoresizingMaskIntoConstraints = false
        capsuleView.layer.cornerRadius = 12
        capsuleView.layer.cornerCurve = .continuous
        capsuleView.layer.shadowOffset = CGSize(width: 0, height: 4)
        capsuleView.layer.shadowRadius = 14
        capsuleView.layer.shadowOpacity = 0.14
        addSubview(capsuleView)

        arrowContainer.translatesAutoresizingMaskIntoConstraints = false
        arrowContainer.layer.cornerRadius = 13
        arrowContainer.layer.cornerCurve = .continuous
        capsuleView.addSubview(arrowContainer)

        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        arrowImageView.image = UIImage(systemName: "arrow.up")
        arrowContainer.addSubview(arrowImageView)

        targetIconView.translatesAutoresizingMaskIntoConstraints = false
        targetIconView.contentMode = .scaleAspectFit
        targetIconView.layer.cornerRadius = 4
        targetIconView.layer.cornerCurve = .continuous
        targetIconView.clipsToBounds = true
        capsuleView.addSubview(targetIconView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "WhitneySSm-Medium", size: 16.5) ?? .systemFont(ofSize: 16.5, weight: .semibold)
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        capsuleView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            capsuleView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            capsuleView.leadingAnchor.constraint(equalTo: leadingAnchor),
            capsuleView.trailingAnchor.constraint(equalTo: trailingAnchor),
            capsuleView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),

            arrowContainer.leadingAnchor.constraint(equalTo: capsuleView.leadingAnchor, constant: 12),
            arrowContainer.centerYAnchor.constraint(equalTo: capsuleView.centerYAnchor),
            arrowContainer.widthAnchor.constraint(equalToConstant: 26),
            arrowContainer.heightAnchor.constraint(equalToConstant: 26),

            arrowImageView.centerXAnchor.constraint(equalTo: arrowContainer.centerXAnchor),
            arrowImageView.centerYAnchor.constraint(equalTo: arrowContainer.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 17),
            arrowImageView.heightAnchor.constraint(equalToConstant: 17),

            targetIconView.leadingAnchor.constraint(equalTo: arrowContainer.trailingAnchor, constant: 10),
            targetIconView.centerYAnchor.constraint(equalTo: capsuleView.centerYAnchor),
            targetIconView.widthAnchor.constraint(equalToConstant: 22),
            targetIconView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: targetIconView.trailingAnchor, constant: 9),
            titleLabel.trailingAnchor.constraint(equalTo: capsuleView.trailingAnchor, constant: -14),
            titleLabel.centerYAnchor.constraint(equalTo: capsuleView.centerYAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 22)
        ])

        updateTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(kind: String, title: String?, icon: UIImage?, progress: CGFloat, ready: Bool) {
        let hasTarget = title?.isEmpty == false
        // FeedDetailViewController.swift names the next folder or site in a complete translated sentence.
        let nextUnread = kind == "folder" ? NBLocalization.text("Next unread folder, %@") : NBLocalization.text("Next unread site, %@")

        titleLabel.text = hasTarget ? title : NBLocalization.text("Feed list")
        accessibilityLabel = hasTarget ? String(format: nextUnread, title ?? "") : NBLocalization.text("Feed list")

        if let icon {
            targetIconView.image = icon.withRenderingMode(.alwaysOriginal)
        } else {
            let fallbackName = kind == "folder" ? "folder.fill" : "globe"
            targetIconView.image = UIImage(systemName: fallbackName)?.withRenderingMode(.alwaysTemplate)
        }

        transform = CGAffineTransform(translationX: 0, y: 12)
        arrowContainer.transform = ready ? CGAffineTransform(scaleX: 1.06, y: 1.06) : .identity

        setReady(ready)
    }

    func updateTheme() {
        capsuleView.backgroundColor = ThemeManager.color(fromRGB: [0xFFFFFF, 0xFAF5ED, 0x3A3A3C, 0x252527]).withAlphaComponent(0.96)
        capsuleView.layer.shadowColor = ThemeManager.shared.isDarkTheme
            ? UIColor.black.cgColor
            : ThemeManager.color(fromRGB: [0x737A84]).cgColor
        capsuleView.layer.borderWidth = 1
        capsuleView.layer.borderColor = ThemeManager.color(fromRGB: [0xE0E4EA, 0xD7CBBB, 0x515153, 0x3A3A3C]).cgColor
        applyReadyState(isReady, animated: false)
    }

    private func setReady(_ ready: Bool) {
        let shouldAnimate = didConfigureReadyState && ready != isReady
        isReady = ready
        didConfigureReadyState = true
        applyReadyState(ready, animated: shouldAnimate)
    }

    private func applyReadyState(_ ready: Bool, animated: Bool) {
        let changes = {
            self.arrowContainer.backgroundColor = ready ? self.activeArrowBackgroundColor : self.inactiveArrowBackgroundColor
            self.arrowImageView.tintColor = ready ? .white : self.inactiveArrowColor
            self.arrowImageView.transform = ready ? CGAffineTransform(rotationAngle: .pi) : .identity
            self.titleLabel.textColor = ready ? self.activeTitleColor : self.inactiveTitleColor
            self.targetIconView.alpha = ready ? 1 : 0.74
            self.targetIconView.tintColor = ready ? self.activeTitleColor : self.inactiveTitleColor
        }

        if animated {
            UIView.animate(withDuration: 0.22,
                           delay: 0,
                           options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut],
                           animations: changes)
        } else {
            changes()
        }
    }

    private var activeArrowBackgroundColor: UIColor {
        ThemeManager.color(fromRGB: [0x477DBF, 0x8A6A33, 0x5A8FD3, 0x5A8FD3])
    }

    private var inactiveArrowBackgroundColor: UIColor {
        ThemeManager.color(fromRGB: [0xDCE2EA, 0xE5D9C8, 0x555557, 0x444446])
    }

    private var activeTitleColor: UIColor {
        ThemeManager.color(fromRGB: [0x2D6EAE, 0x7A5B24, 0x8CBFFF, 0x9DCAFF])
    }

    private var inactiveTitleColor: UIColor {
        ThemeManager.color(fromRGB: [0x2A2D32, 0x3C3226, 0xF2F2F7, 0xF2F2F7])
    }

    private var inactiveArrowColor: UIColor {
        ThemeManager.color(fromRGB: [0x59606A, 0x75685A, 0xD8D8D8, 0xD8D8D8])
    }
}

/// List of stories for a feed.
class FeedDetailViewController: FeedDetailObjCViewController {
    private struct TryFeedRefreshContext: Equatable {
        let account: String
        let host: String
        let feedID: String
        let readFilter: String
        let order: String
        let generation: UInt
    }

    private final class TryFeedRefresh {
        let context: TryFeedRefreshContext
        var poll: DispatchWorkItem?
        var timeout: DispatchWorkItem?

        init(context: TryFeedRefreshContext) { self.context = context }

        func cancel() {
            poll?.cancel()
            timeout?.cancel()
        }
    }

    private var tryFeedRefresh: TryFeedRefresh?
    private var attemptedTryFeedRefresh: TryFeedRefreshContext?
    var tryFeedRefreshPollInterval: TimeInterval { 2 }
    var tryFeedRefreshTimeout: TimeInterval { 60 }

    @objc var isAutomaticallyRefreshingTryFeed: Bool { tryFeedRefresh != nil }

    private var tryFeedRefreshContext: TryFeedRefreshContext? {
        guard let app = appDelegate, let collection = storiesCollection,
              !collection.inSearch, (!app.inFindingStoryMode || app.tryFeedStoryId == nil),
              !collection.isRiverView,
              !collection.isSavedView, !collection.isReadView, !collection.isWidgetView,
              app.isTryFeedView || app.detailViewController?.canReturnToDiscoverSites == true,
              let feedID = collection.activeFeed?["id"],
              let previewID = app.tryFeedFeedId,
              String(describing: feedID) == previewID else { return nil }
        return TryFeedRefreshContext(account: app.activeUsername ?? "", host: app.url ?? "",
                                     feedID: previewID, readFilter: collection.activeReadFilter ?? "all",
                                     order: collection.activeOrder ?? "newest", generation: fetchRequestId)
    }

    override func resetFeedDetail() {
        if isViewLoaded { ReaderMotion.leave(storyTitlesTable) }
        ReaderMotion.session(self).reset()
        storyCache.motionSession.reset()
        if viewIfLoaded?.window == nil {
            ReaderMotion.session(self).prepareForAppearance()
            storyCache.motionSession.prepareForAppearance()
        }
        cancelTryFeedRefresh()
        lastShownStoryLocation = nil
        super.resetFeedDetail()
    }

    override func reloadStories() {
        cancelTryFeedRefresh()
        lastShownStoryLocation = nil
        super.reloadStories()
    }

    override func finishedLoadingFeed(_ results: [AnyHashable: Any]!, feedPage: Int, feedId: String!) {
        super.finishedLoadingFeed(results, feedPage: feedPage, feedId: feedId)
        guard feedPage == 1, let stories = results?["stories"] as? [Any], stories.isEmpty,
              let receivedID = results?["feed_id"], String(describing: receivedID) == feedId,
              let context = tryFeedRefreshContext, context.feedID == feedId,
              attemptedTryFeedRefresh != context else { return }
        startTryFeedRefresh(context)
    }

    override func instafetchFeed() {
        guard tryFeedRefreshContext != nil, storiesCollection.storyCount == 0 else {
            super.instafetchFeed()
            return
        }
        guard tryFeedRefresh == nil else { return }
        fetchRequestId += 1
        guard let context = tryFeedRefreshContext else { return }
        startTryFeedRefresh(context)
    }

    private func cancelTryFeedRefresh() {
        if tryFeedRefresh != nil { finishRefresh() }
        tryFeedRefresh?.cancel()
        tryFeedRefresh = nil
        attemptedTryFeedRefresh = nil
    }

    private func startTryFeedRefresh(_ context: TryFeedRefreshContext) {
        tryFeedRefresh?.cancel()
        let refresh = TryFeedRefresh(context: context)
        tryFeedRefresh = refresh
        attemptedTryFeedRefresh = context
        pageFetching = true
        pageFinished = false
        isOnline = true
        isShowingFetching = true
        messageView.isHidden = true
        showFetchingBanner(NBLocalization.text("Fetching stories from this site..."), isOffline: false)

        let timeout = DispatchWorkItem { [weak self, weak refresh] in
            guard let self, let refresh, self.isCurrentTryFeedRefresh(refresh) else { return }
            self.finishTryFeedRefresh(refresh, response: nil)
        }
        refresh.timeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + tryFeedRefreshTimeout, execute: timeout)
        requestTryFeedRefresh(refresh, force: true)
    }

    private func isCurrentTryFeedRefresh(_ refresh: TryFeedRefresh) -> Bool {
        guard tryFeedRefresh === refresh else { return false }
        guard tryFeedRefreshContext == refresh.context else {
            refresh.cancel()
            tryFeedRefresh = nil
            return false
        }
        return true
    }

    private func requestTryFeedRefresh(_ refresh: TryFeedRefresh, force: Bool) {
        guard isCurrentTryFeedRefresh(refresh) else { return }
        let endpoint = force ? "refresh_feed" : "feed"
        let url = "\(refresh.context.host)/reader/\(endpoint)/\(refresh.context.feedID)"
        var parameters: [String: Any] = ["page": 1, "include_hidden": true,
                                       "read_filter": refresh.context.readFilter, "order": refresh.context.order]
        if !force { parameters["insta_fetch"] = true }
        appDelegate.get(url, parameters: parameters, success: { [weak self, weak refresh] _, object in
            guard let self, let refresh, self.isCurrentTryFeedRefresh(refresh) else { return }
            guard let response = object as? [AnyHashable: Any],
                  let feedID = response["feed_id"], String(describing: feedID) == refresh.context.feedID,
                  let stories = response["stories"] as? [Any] else {
                self.finishTryFeedRefresh(refresh, response: nil)
                return
            }
            if !stories.isEmpty {
                self.finishTryFeedRefresh(refresh, response: response)
            } else if response["has_exception"] as? Bool == true {
                self.finishTryFeedRefresh(refresh, response: nil)
            } else if response["not_yet_fetched"] as? Bool == true || response["fetched_once"] as? Bool == false {
                // reader.js polls unfetched Try feeds until the fetch completes.
                let poll = DispatchWorkItem { [weak self, weak refresh] in
                    guard let self, let refresh else { return }
                    self.requestTryFeedRefresh(refresh, force: false)
                }
                refresh.poll = poll
                DispatchQueue.main.asyncAfter(deadline: .now() + self.tryFeedRefreshPollInterval, execute: poll)
            } else {
                self.finishTryFeedRefresh(refresh, response: response)
            }
        }, failure: { [weak self, weak refresh] _, _ in
            guard let self, let refresh, self.isCurrentTryFeedRefresh(refresh) else { return }
            self.finishTryFeedRefresh(refresh, response: nil)
        })
    }

    private func finishTryFeedRefresh(_ refresh: TryFeedRefresh, response: [AnyHashable: Any]?) {
        guard isCurrentTryFeedRefresh(refresh) else { return }
        refresh.cancel()
        tryFeedRefresh = nil
        if let response {
            storiesCollection.feedPage = 1
            finishedLoadingFeed(response, feedPage: 1, feedId: refresh.context.feedID)
        }
        pageFetching = false
        isShowingFetching = false
        hideFetchingBanner()
        finishRefresh()
        if storiesCollection.storyCount == 0 {
            pageFinished = true
            messageLabel.text = response == nil
                ? NBLocalization.text("Unable to fetch stories. Pull to refresh to try again.")
                : NBLocalization.text("No stories are available from this site yet.")
            messageView.isHidden = false
        }
    }

    private var gridViewController: UIHostingController<FeedDetailGridView>?
    
    private var dashboardViewController: UIHostingController<FeedDetailDashboardView>?

    lazy var storyCache = StoryCache()

    /// The location of the story list row that last came on screen, which StoryScoreRefresher.swift refreshes around.
    private(set) var lastShownStoryLocation: Int?

    
    enum SectionLayoutKind: Int, CaseIterable {
        /// Feed cells before the story.
        case feedBeforeStory
        
        /// The selected story.
        case selectedStory
        
        /// Feed cells after the story.
        case feedAfterStory
        
        /// Loading cell at the end.
        case loading
    }
    
    var wasGridView: Bool {
        return appDelegate.detailViewController.wasGridView
    }
    
    var isExperimental: Bool {
        return appDelegate.detailViewController.style == .experimental || isDashboard
    }
    
    var isSwiftUI: Bool {
        return isGridView || isExperimental
    }

    var feedColumns: Int {
        guard let pref = UserDefaults.standard.string(forKey: "grid_columns"), let columns = Int(pref) else {
            return 4
        }
        
        return columns
    }
    
    var gridHeight: CGFloat {
        guard let pref = UserDefaults.standard.string(forKey: "grid_height") else {
            return 400
        }
        
        switch pref {
        case "xs":
            return 250
        case "short":
            return 300
        case "tall":
            return 400
        case "xl":
            return 450
        default:
            return 350
        }
    }
    
    enum DashboardOperation {
        case none
        case change(DashList)
        case addFirst
        case addBefore(DashList)
        case addAfter(DashList)
    }
    
    var dashboardOperation = DashboardOperation.none
    
    private func makeGridViewController() -> UIHostingController<FeedDetailGridView> {
        let gridView = FeedDetailGridView(feedDetailInteraction: self, cache: storyCache)
        let gridViewController = UIHostingController(rootView: gridView)
        gridViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        return gridViewController
    }
    
    private func makeDashboardViewController() -> UIHostingController<FeedDetailDashboardView> {
        let dashboardView = FeedDetailDashboardView(feedDetailInteraction: self, cache: storyCache)
        let dashboardViewController = UIHostingController(rootView: dashboardView)
        dashboardViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        return dashboardViewController
    }

    private func add(viewController: UIViewController) {
        addChild(viewController)
        view.addSubview(viewController.view)
        viewController.didMove(toParent: self)

        let topAnchor = storyTitlesHeaderBar?.contentTopAnchor ?? view.topAnchor
        NSLayoutConstraint.activate([
            viewController.view.topAnchor.constraint(equalTo: topAnchor),
            viewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            viewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            viewController.view.bottomAnchor.constraint(equalTo:
                storyTitlesHeaderBar?.contentBottomAnchor ?? view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        changedLayout()
    }

    private var isPhoneOrCompactLayout: Bool {
        if let detail = appDelegate.detailViewController {
            return detail.isPhoneOrCompact
        }
        return UIDevice.current.userInterfaceIdiom == .phone || appDelegate.isCompactWidth
    }

    private func correctReturnFrameIfNeeded() {
        guard let navigationController else { return }
        // FeedDetailViewController.swift uses safe-area spacing supplied by the compact phone header.
        if let compactNavigation = navigationController as? CompactPhoneNavigationController,
           !compactNavigation.compactNavigationBar.isHidden {
            return
        }

        let containerBounds = view.superview?.bounds ?? navigationController.view.bounds
        let correctedFrame = FeedDetailReturnFrameDecision.correctedFrame(
            view.frame,
            containerBounds: containerBounds,
            navigationBarMinY: navigationController.navigationBar.frame.minY,
            isPhoneOrCompact: isPhoneOrCompactLayout
        )

        guard correctedFrame != view.frame else { return }

        NSLog(
            "FeedDetailViewController: correcting return frame from \(view.frame) to \(correctedFrame)"
        )

        view.frame = correctedFrame
        view.setNeedsUpdateConstraints()
        view.setNeedsLayout()
        view.layoutIfNeeded()
        view.setNeedsDisplay()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        ReaderMotion.session(self).prepareForAppearance()
        storyCache.motionSession.prepareForAppearance()
        super.viewWillAppear(animated)

        correctReturnFrameIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        correctReturnFrameIfNeeded()
        // FeedDetailViewController.swift starts cached rows after the push and its selection reload have completed.
        ReaderMotion.presentRows(storyTitlesTable, owner: self)
        storyCache.motionSession.didAppear()
    }
    
    @objc override func loadingFeed() {
        // Make sure the view has loaded.
        _ = view

        if appDelegate.detailViewController.isPhoneOrCompact {
            changedLayout()

            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                self.reload()
            }
        } else {
            let wasGridView = wasGridView

            self.appDelegate.detailViewController.updateLayout(reload: false, fetchFeeds: false)

            if wasGridView != isGridView {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                    self.appDelegate.detailViewController.updateLayout(reload: true, fetchFeeds: false)
                }
            }
        }

        if appDelegate.isTryFeedView && tryFeedBannerView == nil {
            showTryFeedSubscribeBanner()
        } else if !appDelegate.isTryFeedView && tryFeedBannerView != nil {
            hideTryFeedSubscribeBanner()
        }
    }
    
    @objc override func changedLayout() {
        // Make sure the view has loaded.
        _ = view

        updateContentVisibility()

        deferredReload()
    }

    private func updateContentVisibility() {
        let shouldShowStoryTitlesTable = isLegacyTable && !isDashboard

        storyTitlesTable.isHidden = !shouldShowStoryTitlesTable

        if let gridViewController {
            gridViewController.view.isHidden = isLegacyTable || isDashboard
        } else if !isLegacyTable && !isDashboard {
            let viewController = makeGridViewController()
            add(viewController: viewController)
            gridViewController = viewController
        }

        if let dashboardViewController {
            dashboardViewController.view.isHidden = !isDashboard
        } else if isDashboard {
            let viewController = makeDashboardViewController()
            add(viewController: viewController)
            dashboardViewController = viewController
        }

        // Keep pill bar above content views
        if let headerContainer = storyTitlesHeaderBar?.headerContainer {
            view.bringSubviewToFront(headerContainer)
        }
    }
    
    var reloadWorkItem: DispatchWorkItem?
    private weak var activeStorySwipeCell: MCSwipeTableViewCell?
    private var reloadDeferredForStorySwipe = false
    
    var pendingStories = [Story.ID : Story]()
    
    @objc var suppressMarkAsRead = false
    
    var scrollingDate = Date.distantPast
    
//    var findingStory: Story?
    
    func deferredReload(story: Story? = nil) {
        reloadWorkItem?.cancel()
        
        if let story {
            pendingStories[story.id] = story
        } else {
            pendingStories.removeAll()
        }
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            
            if pendingStories.isEmpty {
                let secondsSinceScroll = -scrollingDate.timeIntervalSinceNow

                if secondsSinceScroll < 0.5 {
                    deferredReload(story: story)
                    return
                }
                
                configureDataSource()
            } else {
                for story in pendingStories.values {
                    configureDataSource(story: story)
                }
            }
            
            pendingStories.removeAll()
            reloadWorkItem = nil
        }
        
        reloadWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100), execute: workItem)
    }
    
    @objc override func reloadImmediately() {
        configureDataSource()
    }

    @objc override func reloadTable() {
        super.reloadTable()
        appDelegate.detailViewController?.storyTitlesDidReload(self)
    }

    @objc func resetForAccountChange() {
        storiesCollection.reset()
        resetFeedDetail()
        // FeedDetailObjCViewController.m's offline fallback only belongs to a selected feed.
        pageFinished = true
        storiesCollection.inSearch = false
        storiesCollection.searchQuery = nil
        storiesCollection.savedSearchQuery = nil
        storyCache.resetForAccountChange()
        title = nil
        navigationItem.titleView = nil
        // FeedDetailObjCViewController.m uses this same state before any feed is selected.
        messageLabel.text = NBLocalization.text("Select a feed or folder")
        messageView.isHidden = false
        reloadImmediately()
    }

    @objc func resetPendingReloadsForFeedChange() {
        reloadWorkItem?.cancel()
        reloadWorkItem = nil
        pendingStories.removeAll()
        activeStorySwipeCell = nil
        reloadDeferredForStorySwipe = false
        swipingIndexPath = nil
        swipingStoryHash = nil
    }

    override func swipeTableViewCellDidStartSwiping(_ cell: MCSwipeTableViewCell!) {
        super.swipeTableViewCellDidStartSwiping(cell)
        activeStorySwipeCell = cell
    }

    override func swipeTableViewCell(_ cell: MCSwipeTableViewCell!,
                                    didEndSwipingSwipingWith state: MCSwipeTableViewCellState,
                                    mode: MCSwipeTableViewCellMode) {
        guard activeStorySwipeCell === cell else { return }
        super.swipeTableViewCell(cell, didEndSwipingSwipingWith: state, mode: mode)
    }

    override func swipeTableViewCellDidFinishSwiping(_ cell: MCSwipeTableViewCell!) {
        guard activeStorySwipeCell === cell else { return }
        activeStorySwipeCell = nil
        swipingIndexPath = nil
        swipingStoryHash = nil
        if reloadDeferredForStorySwipe {
            reloadDeferredForStorySwipe = false
            deferredReload()
        }
    }
    
    @objc override func reload() {
//        if appDelegate.findingStoryDictionary != nil {
//            findingStory = Story(index: 0, dictionary: appDelegate.findingStoryDictionary)
//        } else if !appDelegate.inFindingStoryMode {
//            findingStory = nil
//        }
        
        deferredReload()
    }
    
    func reload(story: Story) {
        deferredReload(story: story)
    }
    
    @objc override func reload(_ indexPath: IndexPath, with rowAnimation: UITableView.RowAnimation = .none) {
        if !isLegacyTable {
            deferredReload()
        } else if reloadWorkItem == nil, storyTitlesTable.window != nil, swipingStoryHash == nil {
            // Only do this if a deferred reload isn't pending; otherwise no point in doing a partial reload, plus the table may be stale.
            storyTitlesTable.reloadRows(at: [indexPath], with: rowAnimation)
        }
    }
    
    @objc override func doneDashboardChooseSite(_ riverId: String?) {
        guard let riverId else {
            dashboardOperation = .none
            return
        }
        
        switch dashboardOperation {
            case .none:
                break
            case .change(let dashList):
                storyCache.change(dash: dashList, to: riverId)
            case .addFirst:
                storyCache.addFirst(riverId: riverId)
            case .addBefore(let dashList):
                storyCache.add(riverId: riverId, before: true, dash: dashList)
            case .addAfter(let dashList):
                storyCache.add(riverId: riverId, before: false, dash: dashList)
        }
        
        dashboardOperation = .none
    }
}

extension FeedDetailViewController {
    func configureDataSource(story: Story? = nil) {
        // FeedDetailViewController.swift keeps a page response from recycling the cell before its swipe action finishes.
        if activeStorySwipeCell != nil {
            reloadDeferredForStorySwipe = true
            return
        }

        // FeedDetailViewController.swift: the native table reads StoriesCollection directly.
        // Only build StoryCache's complete SwiftUI models when a SwiftUI layout uses them.
        if isLegacyTable {
            reloadTable()
            return
        }

        if isDashboard {
            storyCache.redrawDashboard()
            
            if dashboardIndex < 0 {
                return
            }
        }
        
        if let story {
            storyCache.reload(story: story)
        } else {
            storyCache.reload()
        }
        
//        if findingStory != nil {
//            storyCache.selected = findingStory
//            findingStory = nil
//        }
        
//        if pageFinished, dashboardAwaitingFinish, dashboardIndex >= 0 {
//            dashboardAwaitingFinish = false
//            appDelegate.feedsViewController.loadDashboard()
//        }
    }
    
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard GesturePreferences.storyLongPressShowsMenu || isMac else { return nil }
        let location = storyLocation(for: indexPath)
        guard location >= 0, location < storiesCollection.storyLocationsCount,
              let cell = tableView.cellForRow(at: indexPath) else { return nil }
        let index = storiesCollection.index(fromLocation: location)
        guard index >= 0, index < storiesCollection.activeFeedStories.count,
              let dictionary = storiesCollection.activeFeedStories[index] as? [String: Any] else { return nil }
        let story = Story(index: index, dictionary: dictionary)
        let groups = RowActionMenus.story(story, controller: self, source: cell)
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in RowActionMenus.menu(groups) }
    }

}

extension FeedDetailViewController: FeedDetailInteraction {
    var hasNoMoreStories: Bool {
        return pageFinished
    }
    
    var isPremiumRestriction: Bool {
        return !appDelegate.isPremium &&
        storiesCollection.isRiverView &&
        !storiesCollection.isReadView &&
        !storiesCollection.isWidgetView &&
        !storiesCollection.isSavedView
    }
    
    func pullToRefresh() {
        instafetchFeed()
    }
    
    func tapped(dash: DashList) {
        if dash.isFolder {
            appDelegate.feedsViewController.selectFolder(dash.folderId)
        } else if let feedId = dash.feedId {
            appDelegate.feedsViewController.selectFeed(feedId, inFolder: dash.folderId)
        }
    }
    
    func visible(story: Story) {
        NSLog("🐓 Visible: \(story.debugTitle)")

        guard storiesCollection.activeFeedStories != nil, !isDashboard else {
            return
        }

        lastShownStoryLocation = story.index

        let cacheCount = storyCache.before.count + storyCache.after.count

        if cacheCount > 0, story.index >= cacheCount - 5 {
            if storiesCollection.feedPage >= 100 {
                pageFinished = true
            } else {
                let debug = Date()

                if storiesCollection.isRiverView, storiesCollection.activeFolder != nil {
                    fetchRiverPage(storiesCollection.feedPage + 1, withCallback: nil)
                } else {
                    fetchFeedDetail(storiesCollection.feedPage + 1, withCallback: nil)
                }

                NSLog("🐓 Fetching next page took \(-debug.timeIntervalSinceNow) seconds")
            }
        }
        
        scrollingDate = Date()
    }
    
    func tapped(story: Story, in dash: DashList?) {
        if presentedViewController != nil {
            return
        }
        
        NSLog("🪿 Tapped \(story.debugTitle)")
        
        if isDashboard {
            tappedDashboard(story: story, in: dash)
            return
        }

        let indexPath = IndexPath(row: story.index, section: 0)
        
        suppressMarkAsRead = true
        
        didSelectItem(at: indexPath)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.suppressMarkAsRead = false
        }
    }
    
    func tappedDashboard(story: Story, in dash: DashList?) {
        guard let dash/*, let feedId = story.feed?.id*/ else {
            return
        }
        
        appDelegate.detailViewController.storyTitlesFromDashboardStory = true
        
        appDelegate.inFindingStoryMode = true
        appDelegate.findingStoryStartDate = Date()
        appDelegate.findingStoryDictionary = story.dictionary
        appDelegate.tryFeedStoryId = story.hash
        appDelegate.tryFeedFeedId = dash.feedId
        
        if dash.isFolder {
            appDelegate.feedsViewController.selectFolder(dash.folderId)
        } else if let feedId = dash.feedId {
            appDelegate.feedsViewController.selectFeed(feedId, inFolder: dash.folderId)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.appDelegate.detailViewController.storyTitlesFromDashboardStory = false
        }
    }
    
    func changeDashboard(dash: DashList) {
        self.dashboardOperation = .change(dash)
        
        self.appDelegate.showDashboardSites(dash.riverId)
    }
    
    func addFirstDashboard() {
        self.dashboardOperation = .addFirst
        
        self.appDelegate.showDashboardSites(nil)
    }
    
    func addDashboard(before: Bool, dash: DashList) {
        self.dashboardOperation = before ? .addBefore(dash) : .addAfter(dash)
        
        self.appDelegate.showDashboardSites(nil)
    }
    
    func reloadOneDash(with dash: DashList) {
        self.appDelegate.feedsViewController.reloadOneDash(with: dash.index)
    }
    
    func reading(story: Story) {
        NSLog("🪿 Reading \(story.debugTitle)")
    }
    
    func read(story: Story) {
        if suppressMarkAsRead {
            return
        }
        
        let dict = story.dictionary
        
        if isSwiftUI, appDelegate.feedDetailViewController.markStoryReadIfNeeded(dict, isScrolling: false) {
            NSLog("🪿 Marking as read \(story.debugTitle)")
            
            deferredReload(story: story)
        }
    }
    
    func unread(story: Story) {
        let dict = story.dictionary
        
        if isSwiftUI, !storiesCollection.isStoryUnread(dict) {
            NSLog("🪿 Marking as unread \(story.debugTitle)")
            
            storiesCollection.markStoryUnread(dict)
            storiesCollection.syncStory(asRead: dict)
            
            deferredReload(story: story)
        }
    }
    
    func hid(story: Story) {
        NSLog("🪿 Hiding \(story.debugTitle)")
        
        appDelegate.activeStory = nil
        reload()
    }
    
    func scrolled(story: Story, offset: CGFloat?) {
        let feedDetailHeight = view.frame.size.height
        let storyHeight = appDelegate.storyPagesViewController.currentPage.view.frame.size.height
        let skipHeader: CGFloat = 200
        
        // NSLog("🪿🎛️ Scrolled story \(story.debugTitle) to offset \(offset ?? 0), story height: \(storyHeight), feed detail height: \(feedDetailHeight)")
        
        let gap = appDelegate.storyPagesViewController.traverseBottomGap
        if offset == nil {
            appDelegate.storyPagesViewController.traverseBottomConstraint.constant = storyHeight - feedDetailHeight + gap
        } else if let offset, offset - storyHeight + skipHeader < feedDetailHeight, offset > feedDetailHeight {
            appDelegate.storyPagesViewController.traverseBottomConstraint.constant = offset - feedDetailHeight + gap
        } else {
            appDelegate.storyPagesViewController.traverseBottomConstraint.constant = gap
        }
    }
}
