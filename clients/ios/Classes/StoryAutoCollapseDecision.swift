//
//  StoryAutoCollapseDecision.swift
//  NewsBlur
//
//  Created by Codex on 2026-03-12.
//

import CoreGraphics
import Foundation

#if SWIFT_PACKAGE
// StoryAutoCollapseDecision.swift is also built by clients/ios/Package.swift for its unit tests, without the app's
// NBLocalization.swift (which needs the app delegate), so the package build reads the English badge text.
private enum NBLocalization {
    static var resolvedLanguage: String { "en" }
    static func text(_ source: String) -> String { source }
}
#endif

public enum StoryAutoCollapseBehavior: String {
    case auto
    case tile
    case displace
    case overlay
}

@objc public enum StorySplitPreferredBehavior: Int {
    case tile
    case displace
    case overlay
}

@objc public enum StorySplitPreferredDisplayMode: Int {
    case secondaryOnly
    case oneBesideSecondary
    case oneOverSecondary
    case twoBesideSecondary
    case twoOverSecondary
    case twoDisplaceSecondary
}

@objc public enum SplitCollapseTopColumn: Int {
    case primary
    case secondary
}

@objc public enum FullscreenSidebarPresentation: Int {
    case fullscreen
    case storyTitles
    case feeds
}

@objc public enum FeedSelectionPresentation: Int {
    case loadFeedDetail
    case showFeedsListThenLoadFeedDetail
    case wait
}

@objcMembers public final class StorySplitBehaviorDecision: NSObject {
    public class func shouldShowStoryTitlesBesideTiledFeeds(
        isPhone: Bool,
        isCompact: Bool,
        isDoubleColumn: Bool,
        isDiscoverSitesVisible: Bool,
        storyTitlesOnLeft: Bool,
        displayMode: StorySplitPreferredDisplayMode
    ) -> Bool {
        isPhone && !isCompact && isDoubleColumn && !isDiscoverSitesVisible &&
            storyTitlesOnLeft && displayMode == .oneBesideSecondary
    }

    public class func preferredBehavior(
        for behaviorValue: String?,
        width: CGFloat,
        height: CGFloat,
        isMac: Bool
    ) -> StorySplitPreferredBehavior {
        switch resolvedBehavior(for: behaviorValue, width: width, height: height, isMac: isMac) {
        case .tile:
            return .tile
        case .overlay:
            return .overlay
        default:
            return .displace
        }
    }

    public class func preferredDisplayMode(
        for behaviorValue: String?,
        width: CGFloat,
        height: CGFloat,
        isMac: Bool
    ) -> StorySplitPreferredDisplayMode {
        usesTiledSidebarLayout(for: behaviorValue, width: width, height: height, isMac: isMac)
            ? .twoBesideSecondary
            : .secondaryOnly
    }

    public class func usesTiledSidebarLayout(
        for behaviorValue: String?,
        width: CGFloat,
        height: CGFloat,
        isMac: Bool
    ) -> Bool {
        preferredBehavior(for: behaviorValue, width: width, height: height, isMac: isMac) == .tile
    }

    public class func sidebarDisplayMode(
        forTiledLayout isTiledLayout: Bool,
        currentDisplayMode: StorySplitPreferredDisplayMode
    ) -> StorySplitPreferredDisplayMode {
        if isTiledLayout {
            return currentDisplayMode == .secondaryOnly ? .twoBesideSecondary : .secondaryOnly
        }

        return currentDisplayMode == .secondaryOnly ? .oneOverSecondary : .secondaryOnly
    }

    public class func shouldResetTemporarySidebarReveal(
        for behaviorValue: String?,
        width: CGFloat,
        height: CGFloat,
        isMac: Bool
    ) -> Bool {
        !usesTiledSidebarLayout(for: behaviorValue, width: width, height: height, isMac: isMac)
    }

    private class func resolvedBehavior(
        for behaviorValue: String?,
        width: CGFloat,
        height: CGFloat,
        isMac: Bool
    ) -> StoryAutoCollapseBehavior {
        let requestedBehavior = StoryAutoCollapseBehavior(
            rawValue: behaviorValue ?? StoryAutoCollapseBehavior.auto.rawValue
        ) ?? .auto

        guard requestedBehavior == .auto else {
            return requestedBehavior
        }

        // StoryAutoCollapseDecision.swift keeps the Mac's three panes until the reader explicitly chooses fewer columns.
        if isMac { return .tile }

        // StoryAutoCollapseDecision.swift reserves narrow windows for the title and article panes.
        // Revealing Feeds temporarily overlays those panes instead of squeezing in a third column.
        if width < 1100 {
            return .overlay
        } else if width > height {
            return .tile
        } else {
            return .displace
        }
    }
}

@objcMembers public final class SplitCollapseColumnDecision: NSObject {
    public class func topColumn(
        hasFeed: Bool,
        hasStory: Bool,
        proposedTopColumn _: SplitCollapseTopColumn
    ) -> SplitCollapseTopColumn {
        if hasFeed || hasStory {
            return .secondary
        }

        return .primary
    }

    public class func shouldResetControllers(
        compactStateChanged: Bool,
        hasFeed: Bool,
        hasStory: Bool
    ) -> Bool {
        compactStateChanged && !hasFeed && !hasStory
    }
}

@objcMembers public final class FullscreenSidebarPresentationDecision: NSObject {
    public class func presentation(
        for displayMode: StorySplitPreferredDisplayMode
    ) -> FullscreenSidebarPresentation {
        switch displayMode {
        case .secondaryOnly:
            return .fullscreen
        case .oneBesideSecondary, .oneOverSecondary:
            return .storyTitles
        case .twoBesideSecondary, .twoOverSecondary, .twoDisplaceSecondary:
            return .feeds
        }
    }

    public class func nativeDisplayMode(
        for presentation: FullscreenSidebarPresentation
    ) -> StorySplitPreferredDisplayMode {
        switch presentation {
        case .fullscreen:
            return .secondaryOnly
        case .storyTitles:
            return .oneOverSecondary
        case .feeds:
            return .twoOverSecondary
        }
    }

    public class func needsNativeDisplayModeUpdate(
        for presentation: FullscreenSidebarPresentation,
        currentDisplayMode: StorySplitPreferredDisplayMode
    ) -> Bool {
        self.presentation(for: currentDisplayMode) != presentation
    }

    public class func presentationAfterSidebarTap(
        _ currentPresentation: FullscreenSidebarPresentation
    ) -> FullscreenSidebarPresentation {
        switch currentPresentation {
        case .fullscreen:
            return .storyTitles
        case .storyTitles:
            return .feeds
        case .feeds:
            return .storyTitles
        }
    }

    public class func presentationAfterKeyboardHide(
        _ currentPresentation: FullscreenSidebarPresentation
    ) -> FullscreenSidebarPresentation {
        let _ = currentPresentation
        return .fullscreen
    }

    public class func presentationAfterKeyboardReveal(
        _ currentPresentation: FullscreenSidebarPresentation
    ) -> FullscreenSidebarPresentation {
        let _ = currentPresentation
        return .storyTitles
    }

    public class func presentationAfterStorySelection(
        _ currentPresentation: FullscreenSidebarPresentation
    ) -> FullscreenSidebarPresentation {
        let _ = currentPresentation
        return .fullscreen
    }

    public class func presentationAfterFeedSelection(
        _ currentPresentation: FullscreenSidebarPresentation,
        usesNativeFullscreenSidebar: Bool
    ) -> FullscreenSidebarPresentation {
        let _ = currentPresentation
        return usesNativeFullscreenSidebar ? .fullscreen : .storyTitles
    }

    public class func presentationAfterFullscreenButtonTap(
        _ currentPresentation: FullscreenSidebarPresentation
    ) -> FullscreenSidebarPresentation {
        let _ = currentPresentation
        return .fullscreen
    }

    public class func presentationAfterLeadingEdgeReveal(
        _ currentPresentation: FullscreenSidebarPresentation
    ) -> FullscreenSidebarPresentation {
        presentationAfterKeyboardReveal(currentPresentation)
    }
}

@objcMembers public final class FeedSelectionPresentationDecision: NSObject {
    public class func presentation(
        isPhone: Bool,
        userInterfaceIdiomPhone: Bool
    ) -> FeedSelectionPresentation {
        if !isPhone {
            return .loadFeedDetail
        }

        if userInterfaceIdiomPhone {
            return .showFeedsListThenLoadFeedDetail
        }

        return .wait
    }
}

@objcMembers public final class StorySidebarRevealGestureDecision: NSObject {
    public class func shouldBeginLeadingEdgeStoryTitlesReveal(
        usesOverlay: Bool,
        presentation: FullscreenSidebarPresentation,
        storyTitlesOnLeft: Bool,
        isPhoneOrCompact: Bool
    ) -> Bool {
        guard usesOverlay, storyTitlesOnLeft, !isPhoneOrCompact else {
            return false
        }

        return presentation == .fullscreen
    }
}

@objcMembers public final class FeedSidebarRevealGestureDecision: NSObject {
    public class func shouldBeginLeadingEdgeFeedsReveal(
        presentation: FullscreenSidebarPresentation,
        isPhoneOrCompact: Bool
    ) -> Bool {
        guard !isPhoneOrCompact else {
            return false
        }

        // The feed detail controller only receives this edge gesture while the
        // story titles pane is actually on screen, so cached presentation
        // state should not block the initial reveal gesture.
        let _ = presentation
        return true
    }
}

@objcMembers public final class FetchingBannerAccessoryLayoutDecision: NSObject {
    @objc(fixedAccessoryDimensionForOffline:)
    public class func fixedAccessoryDimension(isOffline: Bool) -> CGFloat {
        isOffline ? 16 : 0
    }

    @objc(revealsAccessoryAfterBannerExpansionForOffline:)
    public class func revealsAccessoryAfterBannerExpansion(isOffline: Bool) -> Bool {
        !isOffline
    }
}

@objcMembers public final class StoryRowLookupDecision: NSObject {
    public class func storyIndex(
        for location: Int,
        visibleStoryLocations: [NSNumber]
    ) -> NSNumber? {
        guard location >= 0 else {
            return nil
        }

        guard visibleStoryLocations.indices.contains(location) else {
            return nil
        }

        return visibleStoryLocations[location]
    }
}

@objcMembers public final class FeedRowLoadingDecision: NSObject {
    public class func shouldShowLoadingCell(
        isLegacyTable: Bool,
        hasRowDescriptor: Bool,
        storyLocation: Int,
        storyCount: Int
    ) -> Bool {
        if isLegacyTable && !hasRowDescriptor {
            return true
        }

        if !isLegacyTable && storyLocation >= storyCount {
            return true
        }

        return false
    }
}

@objcMembers public final class FeedRowScrollReadDecision: NSObject {
    public class func targetStoryLocation(
        rowStoryLocation: NSNumber?,
        storyCount: Int
    ) -> NSNumber? {
        if let rowStoryLocation {
            return rowStoryLocation
        }

        guard storyCount >= 0 else {
            return nil
        }

        return NSNumber(value: storyCount)
    }
}

@objcMembers public final class FeedDetailReturnFrameDecision: NSObject {
    public class func correctedFrame(
        _ frame: CGRect,
        containerBounds: CGRect,
        navigationBarMinY: CGFloat,
        isPhoneOrCompact: Bool
    ) -> CGRect {
        guard isPhoneOrCompact, containerBounds.width > 0 else {
            return frame
        }

        var corrected = frame

        if abs(corrected.minX - containerBounds.minX) > 0.5 ||
            abs(corrected.width - containerBounds.width) > 0.5 {
            corrected.origin.x = containerBounds.minX
            corrected.size.width = containerBounds.width
        }

        if corrected.minY == 0, navigationBarMinY < 0 {
            corrected.origin.y = -navigationBarMinY
        }

        return corrected
    }
}

@objcMembers public final class StoryDetailFullscreenButtonDecision: NSObject {
    public class func showsTemporaryFullscreenButton(
        storyDetailVisible: Bool,
        isPhoneOrCompact: Bool,
        isMac: Bool,
        isUserOverlayMode: Bool,
        isTemporaryFullScreen: Bool
    ) -> Bool {
        guard storyDetailVisible, !isPhoneOrCompact, !isMac else {
            return false
        }

        return isTemporaryFullScreen || !isUserOverlayMode
    }
}

@objcMembers public final class StoryInitialSelectionDecision: NSObject {
    public class func shouldAutomaticallyOpenFirstStory(
        feedOpeningPreference: String?,
        isPhone: Bool,
        isDashboard: Bool,
        usesOverlay: Bool
    ) -> Bool {
        guard !isDashboard else {
            return false
        }

        if usesOverlay && !isPhone {
            return true
        }

        if let feedOpeningPreference {
            return feedOpeningPreference == "story"
        }

        return !isPhone
    }
}

@objcMembers public final class StorySelectionAnimationDecision: NSObject {
    public class func shouldAnimateSelection(
        isPhoneOrCompact: Bool,
        usesNativeFullscreenSidebar: Bool,
        presentation: FullscreenSidebarPresentation,
        isMac: Bool
    ) -> Bool {
        true
    }
}

@objcMembers public final class StorySelectionNavigationDecision: NSObject {
    public class func shouldUseExplicitLocation(
        isPhoneOrCompact: Bool,
        usesNativeFullscreenSidebar: Bool,
        presentation: FullscreenSidebarPresentation
    ) -> Bool {
        guard !isPhoneOrCompact else {
            return false
        }

        let _ = usesNativeFullscreenSidebar
        return presentation != .fullscreen
    }
}

@objcMembers public final class StoryPageChangeDecision: NSObject {
    public class func shouldImmediatelyRealignPages(
        currentPageIndex: Int,
        targetPageIndex: Int,
        animated: Bool
    ) -> Bool {
        !animated && currentPageIndex != targetPageIndex
    }
}

@objcMembers public final class StorySelectionSidebarRefreshDecision: NSObject {
    public class func shouldRefreshStoryTitlesSidebar(
        isPhoneOrCompact: Bool,
        usesNativeFullscreenSidebar: Bool,
        presentation: FullscreenSidebarPresentation
    ) -> Bool {
        guard !isPhoneOrCompact else {
            return true
        }

        let _ = usesNativeFullscreenSidebar
        return presentation == .fullscreen
    }
}

@objcMembers public final class StoryRefreshSelectionDecision: NSObject {
    public class func targetLocation(
        activeStoryLocation: Int,
        storyLocationsCount: Int
    ) -> Int {
        guard storyLocationsCount > 0 else {
            return -1
        }

        if activeStoryLocation >= 0 {
            return activeStoryLocation
        }

        return 0
    }
}

@objcMembers public final class StoryRefreshPagingDecision: NSObject {
    public class func shouldSyncCurrentStoryAfterRefresh(feedPage: Int) -> Bool {
        feedPage <= 1
    }
}

public struct StoryCardFrame: Equatable {
    public let id: String
    public let frame: CGRect

    public init(id: String, frame: CGRect) {
        self.id = id
        self.frame = frame
    }
}

public enum StoryScrollReadDecision {
    public static func frame(for storyID: String, in frames: [StoryCardFrame]) -> CGRect? {
        frames.first { $0.id == storyID }?.frame
    }

    public static func shouldMarkRead(storyID: String, frames: [StoryCardFrame]) -> Bool {
        guard let frame = frame(for: storyID, in: frames) else {
            return false
        }

        return frame.minY < -(frame.height / 2)
    }
}

@objcMembers public final class StoryClusterDisplayDecision: NSObject {
    @objc(isClusterMarkReadEnabledWithUserProfile:)
    public class func isClusterMarkReadEnabled(userProfile: NSDictionary?) -> Bool {
        guard let preferences = preferencesDictionary(from: userProfile) else {
            return false
        }

        guard let value = preferences["cluster_mark_read"] else {
            return false
        }

        return boolValue(from: value)
    }

    @objc(effectiveClusterReadStatusWithIsClusterRead:parentRead:clusterMarkReadEnabled:isPremiumArchive:)
    public class func effectiveClusterReadStatus(
        isClusterRead: Bool,
        parentRead: Bool,
        clusterMarkReadEnabled: Bool,
        isPremiumArchive: Bool
    ) -> Bool {
        guard isPremiumArchive, clusterMarkReadEnabled, parentRead else {
            return isClusterRead
        }

        return true
    }

    @objc(updatedClusterStories:parentRead:clusterMarkReadEnabled:isPremiumArchive:)
    public class func updatedClusterStories(
        _ clusterStories: NSArray?,
        parentRead: Bool,
        clusterMarkReadEnabled: Bool,
        isPremiumArchive: Bool
    ) -> NSArray {
        guard
            let clusterStories,
            effectiveClusterReadStatus(
                isClusterRead: false,
                parentRead: parentRead,
                clusterMarkReadEnabled: clusterMarkReadEnabled,
                isPremiumArchive: isPremiumArchive
            )
        else {
            return clusterStories ?? []
        }

        return clusterStories.compactMap { item in
            guard let story = item as? NSDictionary else {
                return item
            }

            let updatedStory = NSMutableDictionary(dictionary: story)
            updatedStory["read_status"] = 1
            return updatedStory.copy()
        } as NSArray
    }

    @objc(indicatorImageNameForScore:)
    public class func indicatorImageName(forScore score: Int) -> String {
        if score < 0 {
            return "indicator-hidden"
        } else if score > 0 {
            return "indicator-focus"
        } else {
            return "indicator-unread"
        }
    }

    @objc(normalizedClusterTierValue:)
    public class func normalizedClusterTierValue(_ value: Any?) -> String {
        normalizedClusterTier(from: value)
    }

    // StoryAutoCollapseDecision.swift translates the badge shown on cluster rows, cards and the story detail.
    @objc(clusterTierLabelForValue:)
    public class func clusterTierLabel(forValue value: Any?) -> String {
        normalizedClusterTier(from: value) == "title" ? NBLocalization.text("Match") : NBLocalization.text("Related")
    }

    // StoryAutoCollapseDecision.swift capitalizes the badge with the interface language's casing rules, so Turkish
    // keeps its dotted capital I.
    @objc(clusterTierBadgeTextForValue:)
    public class func clusterTierBadgeText(forValue value: Any?) -> String {
        clusterTierLabel(forValue: value).uppercased(with: Locale(identifier: NBLocalization.resolvedLanguage))
    }

    @objc(visibleClusterStories:subscribedFeedIds:isPremiumArchive:)
    public class func visibleClusterStories(
        _ clusterStories: NSArray?,
        subscribedFeedIds: NSSet?,
        isPremiumArchive: Bool
    ) -> NSArray {
        guard
            let clusterStories = clusterStories as? [NSDictionary],
            let subscribedFeedIds
        else {
            return []
        }

        let allowedFeedIds = Set(subscribedFeedIds.compactMap { stringValue(from: $0) })
        let visibleClusterStories = clusterStories
            .filter { clusterStory in
                guard let feedId = stringValue(from: clusterStory["story_feed_id"]) else {
                    return false
                }

                return allowedFeedIds.contains(feedId)
            }
            .sorted { lhs, rhs in
                timestamp(from: lhs) > timestamp(from: rhs)
            }

        guard !isPremiumArchive, visibleClusterStories.count > 1 else {
            return visibleClusterStories as NSArray
        }

        return Array(visibleClusterStories.prefix(1)) as NSArray
    }

    @objc(canSafelyReloadClusterRowsWithCurrentTableRowCount:visibleStoryRowCount:targetRows:)
    public class func canSafelyReloadClusterRows(
        currentTableRowCount: Int,
        visibleStoryRowCount: Int,
        targetRows: NSArray?
    ) -> Bool {
        guard let targetRows = targetRows as? [NSNumber], !targetRows.isEmpty else {
            return false
        }

        let expectedTableRowCount = visibleStoryRowCount + 1
        guard currentTableRowCount == expectedTableRowCount else {
            return false
        }

        return targetRows.allSatisfy { targetRow in
            let row = targetRow.intValue
            return row >= 0 && row < currentTableRowCount
        }
    }

    private class func preferencesDictionary(from userProfile: NSDictionary?) -> NSDictionary? {
        guard let preferencesValue = userProfile?["preferences"] else {
            return nil
        }

        if let preferences = preferencesValue as? NSDictionary {
            return preferences
        }

        guard
            let preferencesJSON = preferencesValue as? String,
            let data = preferencesJSON.data(using: .utf8),
            let preferences = try? JSONSerialization.jsonObject(with: data) as? NSDictionary
        else {
            return nil
        }

        return preferences
    }

    private class func boolValue(from value: Any) -> Bool {
        if let boolValue = value as? Bool {
            return boolValue
        }

        if let numberValue = value as? NSNumber {
            return numberValue.boolValue
        }

        if let stringValue = value as? String {
            return NSString(string: stringValue).boolValue
        }

        return false
    }

    private class func normalizedClusterTier(from value: Any?) -> String {
        guard let stringValue = stringValue(from: value) else {
            return "related"
        }

        return stringValue == "title" ? "title" : "related"
    }

    private class func stringValue(from value: Any?) -> String? {
        guard let value else {
            return nil
        }

        if let stringValue = value as? String, !stringValue.isEmpty {
            return stringValue
        }

        if let numberValue = value as? NSNumber {
            return numberValue.stringValue
        }

        return nil
    }

    private class func timestamp(from clusterStory: NSDictionary) -> Int {
        if let timestamp = clusterStory["story_timestamp"] as? NSNumber {
            return timestamp.intValue
        }

        if let timestamp = clusterStory["story_timestamp"] as? NSString {
            return timestamp.integerValue
        }

        return 0
    }
}

@objcMembers public final class TryFeedPresentationDecision: NSObject {
    @objc(isTryFeedPreviewWithFeed:)
    public class func isTryFeedPreview(feed: NSDictionary?) -> Bool {
        guard let value = feed?["temp"] else {
            return false
        }

        if let boolValue = value as? Bool {
            return boolValue
        }

        if let numberValue = value as? NSNumber {
            return numberValue.boolValue
        }

        if let stringValue = value as? String {
            return NSString(string: stringValue).boolValue
        }

        return false
    }
}

@objcMembers public final class StoryPageRefreshDecision: NSObject {
    public class func shouldBeginRefresh(isRefreshInProgress: Bool) -> Bool {
        !isRefreshInProgress
    }
}

@objcMembers public final class StoryTraverseFadeDecision: NSObject {
    public class func accumulator(
        currentAccumulator: CGFloat,
        deltaY: CGFloat,
        fadeDistance: CGFloat,
        isUserScroll: Bool
    ) -> CGFloat {
        let clampedCurrent = max(0, min(fadeDistance, currentAccumulator))

        guard isUserScroll else {
            return clampedCurrent
        }

        return max(0, min(fadeDistance, clampedCurrent + deltaY))
    }

    public class func alpha(
        accumulator: CGFloat,
        fadeDistance: CGFloat
    ) -> CGFloat {
        guard fadeDistance > 0 else {
            return 1
        }

        let clampedAccumulator = max(0, min(fadeDistance, accumulator))
        return 1 - (clampedAccumulator / fadeDistance)
    }
}

public struct StoryAutoCollapseDecision {
    public static func shouldCollapse(
        isPhone: Bool,
        isCompact: Bool,
        hasActiveStory: Bool,
        behavior: StoryAutoCollapseBehavior,
        size: CGSize,
        isMac: Bool
    ) -> Bool {
        guard !isPhone, !isCompact, hasActiveStory else {
            return false
        }

        switch behavior {
        case .tile:
            return false
        case .auto, .displace:
            return false
        case .overlay:
            return true
        }
    }

    public static func resolvedShouldCollapse(
        baseShouldCollapse: Bool,
        fullscreenSidebarPresentation: FullscreenSidebarPresentation,
        usesNativeFullscreenSidebar: Bool,
        isTemporaryFullScreen: Bool
    ) -> Bool {
        if usesNativeFullscreenSidebar || isTemporaryFullScreen {
            return true
        }

        return fullscreenSidebarPresentation == .fullscreen ? baseShouldCollapse : false
    }
}
