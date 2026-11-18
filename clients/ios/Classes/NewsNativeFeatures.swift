import Foundation

/// NewsNativeFeatures.swift: NewsBlur features NewsNative sets aside. The code behind each stays in place;
/// these switches hide every entry point so the app never offers them. Turning one on restores its entry points.
@objcMembers final class NewsNativeFeatures: NSObject {
    /// Infrequent Site Stories, Global Shared Stories, Widely Read Stories, Long Reads and Good Reads in the feed list.
    static let showsSpecialFeedSections = false
    /// The account header above the feed list: avatar, username, unread counts and the sync status pill.
    static let showsAccountHeader = false
    /// Social reading: All Shared Stories and the shared stories of people you follow in the feed list and dashboard
    /// picker, Interactions, and Find Friends.
    static let socialFeatures = false
    /// Public comments under a story, from people you don't follow, and the Preferences toggle that shows them.
    static let publicComments = false

    /// The feed-list folders shown only when `showsSpecialFeedSections` is on (FeedsObjCViewController.m).
    static let specialFeedFolders: Set<String> = ["river_global", "trending:well_read", "trending:long_reads",
                                                  "trending:good_reads"]
}
