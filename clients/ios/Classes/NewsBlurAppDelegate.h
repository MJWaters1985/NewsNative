//
//  NewsBlurAppDelegate.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SafariServices/SafariServices.h>
#import "BaseViewController.h"
#import "FMDatabaseQueue.h"
#import "AFNetworking.h"

#define FEED_DETAIL_VIEW_TAG 1000001
#define STORY_DETAIL_VIEW_TAG 1000002
#define FEED_TITLE_GRADIENT_TAG 100003
#define SHARE_MODAL_HEIGHT 120
#define STORY_TITLES_HEIGHT 240

@class AppDelegateHelper;
@class SplitViewController;
@class FeedsViewController;
@class FeedDetailViewController;
@class MarkReadMenuViewController;
@class FontSettingsViewController;
@class DetailViewController;
@class StoryPagesViewController;
@class StoryDetailViewController;
@class LoginViewController;
@class AddSiteViewController;
@class MoveSiteViewController;
@class UserTagsViewController;
@class OriginalStoryViewController;
@class FeedChooserViewController;
@class MenuViewController;
@class UnreadCounts;
@class StoriesCollection;
@class PINCache;
@class WKWebView;
@class BGAppRefreshTask;
@class FeedIconPreparationRequest;
@class StoryScoreRefresher;

@interface NewsBlurAppDelegate : BaseViewController
<UIApplicationDelegate, UINavigationControllerDelegate, UIPopoverPresentationControllerDelegate,
SFSafariViewControllerDelegate, UIGestureRecognizerDelegate>  {
    UINavigationController *ftuxNavigationController;
    UINavigationController *feedsNavigationController;
    UINavigationController *modalNavigationController;
    UINavigationController *shareNavigationController;
    DetailViewController *detailViewController;
    
    
    FeedsViewController *feedsViewController;
    FontSettingsViewController *fontSettingsViewController;
    
    StoryDetailViewController *storyDetailViewController;
    LoginViewController *loginViewController;
    AddSiteViewController *addSiteViewController;
    MoveSiteViewController *moveSiteViewController;
    UserTagsViewController *userTagsViewController;
    OriginalStoryViewController *originalStoryViewController;
    UINavigationController *originalStoryViewNavController;

    AFHTTPSessionManager *networkManager;

    NSString * activeUsername;
    BOOL hasNoSites;
    BOOL isTryFeedView;
    BOOL skipTryFeedCleanup;
    BOOL popoverHasFeedView;
    BOOL inFeedDetail;
    BOOL inStoryDetail;
    BOOL inFindingStoryMode;
    BOOL hasLoadedFeedDetail;
    BOOL hasQueuedReadStories;
    NSString *tryFeedStoryId;
    NSString *tryFeedFeedId;
    
    NSDictionary * activeStory;
    NSURL * activeOriginalStoryURL;
    NSInteger feedDetailPortraitYCoordinate;
    NSInteger originalStoryCount;
    NSInteger selectedIntelligence;
    NSInteger savedStoriesCount;
    NSInteger totalUnfetchedStoryCount;
    NSInteger remainingUnfetchedStoryCount;
    NSInteger latestFetchedStoryDate;
    NSInteger latestCachedImageDate;
    NSInteger totalUncachedImagesCount;
    NSInteger remainingUncachedImagesCount;
    NSMutableDictionary * recentlyReadStories;
    NSMutableSet * recentlyReadFeeds;
    NSMutableArray * readStories;
    NSMutableDictionary *folderCountCache;
    NSMutableDictionary *collapsedFolders;
    UIFontDescriptor *fontDescriptorTitleSize;
    
	NSDictionary * dictFolders;
    NSMutableDictionary * dictFeeds;
    NSMutableDictionary * dictActiveFeeds;
    NSDictionary * dictSocialProfile;
    NSDictionary * dictUserProfile;
    NSDictionary * dictSocialServices;
    NSMutableDictionary * dictUnreadCounts;
    NSMutableDictionary * dictTextFeeds;
    NSMutableArray * dictFoldersArray;
    
    FMDatabaseQueue *database;
    NSOperationQueue *offlineQueue;
    NSOperationQueue *offlineCleaningQueue;
    NSOperationQueue *cacheImagesOperationQueue;
    NSArray *categories;
    NSDictionary *categoryFeeds;
    UIImageView *splashView;
    NSMutableDictionary *activeCachedImages;
    
    PINCache *cachedFavicons;
    PINCache *cachedStoryImages;
    PINCache *cachedUserAvatars;
}

@property (class, nonatomic, readonly) NewsBlurAppDelegate *shared;
@property (class, nonatomic, readonly) AppDelegateHelper *helper;
@property (nonatomic, readonly) AppDelegateHelper *helper;

@property (nonatomic, readonly) NSURL *documentsURL;
@property (nonatomic) SplitViewController *splitViewController;
@property (nonatomic) IBOutlet UINavigationController *ftuxNavigationController;
@property (nonatomic) IBOutlet UINavigationController *feedsNavigationController;
@property (nonatomic) IBOutlet UINavigationController *feedDetailNavigationController;
@property (nonatomic) IBOutlet UINavigationController *detailNavigationController;
@property (nonatomic) UINavigationController *modalNavigationController;
@property (nonatomic) UINavigationController *shareNavigationController;
@property (nonatomic) UINavigationController *originalStoryViewNavController;
@property (nonatomic) IBOutlet DetailViewController *detailViewController;
@property (nonatomic) IBOutlet FeedsViewController *feedsViewController;
@property (nonatomic, readonly) FeedDetailViewController *feedDetailViewController;
@property (nonatomic, strong) UINavigationController *feedDetailMenuNavigationController;
@property (nonatomic, readonly) StoryPagesViewController *storyPagesViewController;
@property (nonatomic) IBOutlet StoryDetailViewController *storyDetailViewController;
@property (nonatomic) IBOutlet LoginViewController *loginViewController;
@property (nonatomic, strong) UINavigationController *addSiteNavigationController;
@property (nonatomic) IBOutlet AddSiteViewController *addSiteViewController;
@property (nonatomic) IBOutlet MoveSiteViewController *moveSiteViewController;
@property (nonatomic) IBOutlet UserTagsViewController *userTagsViewController;
@property (nonatomic) IBOutlet OriginalStoryViewController *originalStoryViewController;
@property (nonatomic) IBOutlet FontSettingsViewController *fontSettingsViewController;
@property (nonatomic, strong) UINavigationController *fontSettingsNavigationController;
@property (nonatomic, strong) MarkReadMenuViewController *markReadMenuViewController;
@property (nonatomic, strong) FeedChooserViewController *feedChooserViewController;

@property (nonatomic) AFHTTPSessionManager *networkManager;
@property (nonatomic, readwrite) StoriesCollection *storiesCollection;
/// NewsBlurAppDelegate.m asks StoryScoreRefresher.swift for the loaded stories' scores after each classifier save.
@property (nonatomic, readonly) StoryScoreRefresher *storyScoreRefresher;
@property (nonatomic, readwrite) PINCache *cachedFavicons;
@property (nonatomic, readwrite) PINCache *cachedStoryImages;
@property (nonatomic, readwrite) PINCache *cachedUserAvatars;

@property (nonatomic, readonly) NSString *url;
@property (nonatomic, readonly) NSString *host;

@property (nonatomic, readonly) NSHTTPCookie *sessionIdCookie;
@property (readwrite) NSString * activeUsername;
@property (nonatomic, readwrite) BOOL hasNoSites;
@property (nonatomic, readwrite) BOOL isTryFeedView;
@property (nonatomic, readwrite) BOOL skipTryFeedCleanup;
@property (nonatomic, readwrite) BOOL inFindingStoryMode;
@property (nonatomic, readwrite) BOOL hasLoadedFeedDetail;
@property (nonatomic, readwrite) NSDate *findingStoryStartDate;
@property (nonatomic) NSDictionary *findingStoryDictionary;
@property (nonatomic) NSString *tryFeedStoryId;
@property (nonatomic) NSString *tryFeedFeedId;
@property (nonatomic) NSString *tryFeedStoryTitle;
@property (nonatomic, readwrite) BOOL popoverHasFeedView;
@property (nonatomic, readwrite) BOOL inFeedDetail;
@property (nonatomic, readwrite) BOOL inStoryDetail;
@property (nonatomic, readwrite) BOOL isPresentingActivities;
@property (readwrite) NSDictionary * activeStory;
@property (readwrite) NSURL * activeOriginalStoryURL;
@property (readwrite) NSInteger feedDetailPortraitYCoordinate;
@property (readwrite) NSInteger originalStoryCount;
@property (readwrite) NSInteger savedSearchesCount;
@property (readwrite) NSInteger savedStoriesCount;
@property (readwrite) NSInteger totalUnfetchedStoryCount;
@property (readwrite) NSInteger remainingUnfetchedStoryCount;
@property (readwrite) NSInteger totalUncachedTextCount;
@property (readwrite) NSInteger remainingUncachedTextCount;
@property (readwrite) NSInteger totalUncachedImagesCount;
@property (readwrite) NSInteger remainingUncachedImagesCount;
@property (readwrite) NSInteger latestFetchedStoryDate;
@property (readwrite) NSInteger latestCachedTextDate;
@property (readwrite) NSInteger latestCachedImageDate;
@property (readwrite) NSInteger selectedIntelligence;
@property (readwrite) NSMutableDictionary * recentlyReadStories;
@property (readwrite) NSMutableSet * recentlyReadFeeds;
@property (readwrite) NSMutableArray * readStories;
@property (readwrite) NSMutableDictionary *unreadStoryHashes;
@property (readwrite) NSMutableDictionary *unsavedStoryHashes;
@property (nonatomic) NSMutableDictionary *folderCountCache;
@property (nonatomic) NSMutableDictionary *collapsedFolders;
@property (nonatomic) UIFontDescriptor *fontDescriptorTitleSize;

@property (nonatomic) NSDictionary *dictFolders;
@property (nonatomic, strong) NSMutableDictionary *dictFeeds;
@property (nonatomic, strong) NSMutableDictionary *dictInactiveFeeds;
@property (nonatomic) NSMutableDictionary *dictActiveFeeds;
@property (nonatomic, strong) NSDictionary *dictSubfolders;
@property (nonatomic) NSDictionary *dictSavedStoryTags;
@property (nonatomic, strong) NSDictionary *dictSavedStoryFeedCounts;
@property (nonatomic) NSDictionary *dictSocialProfile;
@property (nonatomic) NSDictionary *dictUserProfile;
@property (nonatomic) NSDictionary *dictSocialServices;
@property (nonatomic) BOOL isPremium;
@property (nonatomic) BOOL isPremiumArchive;
@property (nonatomic) BOOL isPremiumPro;
@property (nonatomic) NSInteger premiumExpire;
@property (nonatomic, strong) NSMutableDictionary *dictUnreadCounts;
@property (nonatomic, strong) NSMutableDictionary *dictTextFeeds;
@property (nonatomic) NSMutableArray *dictFoldersArray;
@property (nonatomic) NSArray *dashboardArray;
@property (nonatomic) NSDictionary *dictFolderIcons;
@property (nonatomic) NSDictionary *dictFeedIcons;

@property (nonatomic, readonly) NSString *widgetFolder;
@property (nonatomic, strong) NSString *pendingFolder;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *pendingNotificationStory;

@property (nonatomic) NSArray *categories;
@property (nonatomic) NSDictionary *categoryFeeds;
@property (readwrite) FMDatabaseQueue *database;
@property (nonatomic) NSOperationQueue *offlineQueue;
@property (atomic) BOOL clearingOfflineCache;
@property (nonatomic) NSOperationQueue *offlineCleaningQueue;
@property (nonatomic) NSOperationQueue *cacheImagesOperationQueue;
@property (nonatomic) NSMutableDictionary *activeCachedImages;
@property (nonatomic, readwrite) BOOL hasQueuedReadStories;
@property (nonatomic, readwrite) BOOL hasQueuedSavedStories;
@property (nonatomic, readonly) BOOL showingSafariViewController;
//@property (nonatomic) CGFloat compactWidth;

@property (nonatomic, strong) BGAppRefreshTask *backgroundAppRefreshTask;

+ (instancetype)sharedAppDelegate;

- (void)registerDefaultsFromSettingsBundle;
- (void)finishBackground;
- (void)prepareViewControllers;

- (BOOL)openURL:(NSURL *)url;

- (void)showLogin;
- (void)setupReachability;
- (void)registerForBadgeNotifications;

- (void)showSendTo:(UIViewController *)vc sender:(id)sender;
- (void)showSendTo:(UIViewController *)vc sender:(id)sender
           withUrl:(NSURL *)url
        authorName:(NSString *)authorName
              text:(NSString *)text
             title:(NSString *)title
         feedTitle:(NSString *)title
            images:(NSArray *)images;
- (void)showMuteSites;
- (void)showOrganizeSites;
- (void)showWidgetSites;
- (void)showDashboardSites:(NSString *)selectedRiverId;
- (void)updateSplitBehavior:(BOOL)refresh;
- (void)addSplitControlToMenuController:(MenuViewController *)menuViewController;
- (void)showPreferences;
- (void)showKeyboardShortcuts;
- (void)resizePreviewSize;
- (void)resizeFontSize;
- (void)popToRootWithCompletion:(void (^)(void))completion;
- (void)showColumn:(UISplitViewControllerColumn)column debugInfo:(NSString *)debugInfo animated:(BOOL)animated;

- (void)showFirstTimeUser;
- (void)showMoveSite;
- (void)openStatisticsWithFeed:(NSString *)feedId sender:(id)sender;
- (void)openAddSiteWithFeedAddress:(NSString *)feedAddress;
- (void)openDiscoverSitesView;
- (void)cleanUpTryFeed;
- (void)openUserTagsStory:(id)sender;
- (void)loadFeedDetailView;
- (void)loadFeedDetailView:(BOOL)transition;
- (void)loadFeed:(NSString *)feedId withStory:(NSString *)contentId animated:(BOOL)animated;
- (void)loadFeed:(NSString *)feedId
       withStory:(NSString *)contentId
      storyTitle:(NSString *)storyTitle
        animated:(BOOL)animated;
- (void)loadTryFeedDetailView:(NSString *)feedId withStory:(NSString *)contentId withUser:(NSDictionary *)user showFindingStory:(BOOL)showHUD;
- (void)addTryFeedToSidebar:(NSDictionary *)feed;
- (void)removeTryFeedFromSidebar;
- (void)backgroundLoadNotificationStory;
- (void)loadStarredDetailViewWithStory:(NSString *)contentId showFindingStory:(BOOL)showHUD;
- (void)loadRiverFeedDetailView:(FeedDetailViewController *)feedDetailView withFolder:(NSString *)folder;

- (void)loadStoryDetailView;
- (void)loadStoryDetailViewAnimated:(BOOL)animated;
- (void)loadStoryDetailViewAtLocation:(NSInteger)location animated:(BOOL)animated;
- (void)adjustStoryDetailWebView;
- (void)calibrateStoryTitles;
- (void)recalculateIntelligenceScores:(id)feedId;
- (void)showRescoredStories:(NSArray *)stories;

- (void)cancelRequests;
- (void)resetNetworkManagerForTesting;
- (void)setCustomDomainForTesting:(NSString *)urlString;
// NewsBlurAppDelegate.m: saves the server address (blank uses the default) and resets connections if it changed.
- (void)applyCustomServer:(NSString *)serverString;
+ (NSString *)normalizedServerURL:(NSString *)serverString;
+ (NSString *)defaultServerURL;
- (void)setNetworkProtocolClassesForTesting:(NSArray<Class> *)protocolClasses;
- (void)replaceUnreadCountsForTesting:(NSArray<NSDictionary *> *)unreadRows;
- (NSString *)beginNetworkOperation;
- (void)endNetworkOperation:(NSString *)networkOperationIdentifier;

- (void)GET:(NSString *)urlString parameters:(id)parameters
    success:(void (^)(NSURLSessionDataTask *, id))success
    failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;
- (NSURLSessionDataTask *)GETreturningTask:(NSString *)urlString parameters:(id)parameters
    success:(void (^)(NSURLSessionDataTask *, id))success
    failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;
- (void)GET:(NSString *)urlString parameters:(id)parameters target:(id)target
    success:(SEL)success
    failure:(SEL)failure;
- (void)POST:(NSString *)urlString parameters:(id)parameters
     success:(void (^)(NSURLSessionDataTask *, id))success
     failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;
- (void)POST:(NSString *)urlString parameters:(id)parameters target:(id)target
     success:(SEL)success
     failure:(SEL)failure;

- (void)prepareWebView:(WKWebView *)webView completionHandler:(void (^)(void))completion;

- (void)handleUserActivity:(NSUserActivity *)activity;
- (void)loadFolder:(NSString *)folder feedID:(NSString *)feedIdStr;
- (void)reloadFeedsView:(BOOL)showLoader;
- (void)finishAuthentication;
- (void)setTitle:(NSString *)title;
- (void)showOriginalStory:(NSURL *)url;
- (void)showOriginalStory:(NSURL *)url sender:(id)sender;
- (void)showInAppBrowser:(NSURL *)url withCustomTitle:(NSString *)customTitle fromSender:(id)sender;
- (void)showSafariViewControllerWithURL:(NSURL *)url useReader:(BOOL)useReader;
- (void)closeOriginalStory;
- (void)hideStoryDetailView;
- (void)showFeedsListAnimated:(BOOL)animated;
- (void)changeActiveFeedDetailRow;
- (BOOL)isSavedSearch:(NSString *)feedIdStr;
- (BOOL)isSavedFeed:(NSString *)feedIdStr;
- (NSInteger)savedStoriesCountForFeed:(NSString *)feedIdStr;
- (BOOL)isSavedStoriesIntelligenceMode;
- (NSArray *)allFeedIds;
- (NSArray *)feedIdsForTopLevelRiverWithReadFilter:(NSString *)readFilter;
- (NSArray *)feedIdsForFolderTitle:(NSString *)folderTitle;
- (void)confirmLogout;
- (void)showAlert:(UIAlertController *)alert withViewController:(UIViewController *)vc;
- (void)refreshUserProfile:(void(^)(void))callback;
- (void)refreshFeedCount:(id)feedId;

- (void)donateRefresh;
- (void)donateFolder;
- (void)donateFeed;

- (void)populateDictTextFeeds;
- (BOOL)isFeedInTextView:(id)feedId;
- (void)toggleFeedTextView:(id)feedId;

- (void)populateDictUnreadCounts;
- (NSInteger)unreadCount;
- (NSInteger)allUnreadCount;
- (NSInteger)unreadCountForFeed:(NSString *)feedId;
- (NSInteger)unreadCountForFolder:(NSString *)folderName;
- (UnreadCounts *)splitUnreadCountForFeed:(NSString *)feedId;
- (UnreadCounts *)splitUnreadCountForFolder:(NSString *)folderName;
- (NSDictionary *)markVisibleStoriesRead;

- (void)markActiveFolderAllRead;
- (void)markFeedAllRead:(id)feedId;
- (void)markFeedReadInCache:(NSArray *)feedIds;
- (void)markFeedReadInCache:(NSArray *)feedIds cutoffTimestamp:(NSInteger)cutoff;
- (void)markFeedReadInCache:(NSArray *)feedIds cutoffTimestamp:(NSInteger)cutoff older:(BOOL)older;
- (void)markStoriesRead:(NSDictionary *)stories inFeeds:(NSArray *)feeds cutoffTimestamp:(NSInteger)cutoff;
- (void)finishMarkAsRead:(NSDictionary *)story;
- (void)finishMarkAsUnread:(NSDictionary *)story;
- (void)failedMarkAsUnread:(NSDictionary *)params;
- (void)finishMarkAsSaved:(NSDictionary *)params;
- (void)failedMarkAsSaved:(NSDictionary *)params;
- (void)finishMarkAsUnsaved:(NSDictionary *)params;
- (void)failedMarkAsUnsaved:(NSDictionary *)params;
- (NSInteger)adjustSavedStoryCount:(NSString *)tagName direction:(NSInteger)direction;
- (NSArray *)updateStarredStoryCounts:(NSDictionary *)results;
- (NSArray *)updateSavedSearches:(NSDictionary *)results;
- (void)renameFeed:(NSString *)newTitle;
- (void)renameFolder:(NSString *)newTitle;

- (void)showMarkReadMenuWithFeedIds:(NSArray *)feedIds collectionTitle:(NSString *)collectionTitle visibleUnreadCount:(NSInteger)visibleUnreadCount barButtonItem:(UIBarButtonItem *)barButtonItem completionHandler:(void (^)(BOOL marked))completionHandler;
- (void)showMarkReadMenuWithFeedIds:(NSArray *)feedIds collectionTitle:(NSString *)collectionTitle visibleUnreadCount:(NSInteger)visibleUnreadCount sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect completionHandler:(void (^)(BOOL marked))completionHandler;
- (void)showMarkReadMenuWithFeedIds:(NSArray *)feedIds collectionTitle:(NSString *)collectionTitle sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect completionHandler:(void (^)(BOOL marked))completionHandler;
- (void)showMarkOlderNewerReadMenuWithStoriesCollection:(StoriesCollection *)olderNewerCollection story:(NSDictionary *)olderNewerStory sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect extraItems:(NSArray *)extraItems completionHandler:(void (^)(BOOL marked))completionHandler;

- (void)showPopoverWithViewController:(UIViewController *)viewController contentSize:(CGSize)contentSize sender:(id)sender;
- (void)showPopoverWithViewController:(UIViewController *)viewController contentSize:(CGSize)contentSize barButtonItem:(UIBarButtonItem *)barButtonItem;
- (void)showPopoverWithViewController:(UIViewController *)viewController contentSize:(CGSize)contentSize sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect;
- (void)showPopoverWithViewController:(UIViewController *)viewController contentSize:(CGSize)contentSize sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect permittedArrowDirections:(UIPopoverArrowDirection)permittedArrowDirections;

- (void)hidePopoverAnimated:(BOOL)animated completion:(void (^)(void))completion;
- (BOOL)hidePopoverAnimated:(BOOL)animated;
- (void)hidePopover;

+ (int)computeStoryScore:(NSDictionary *)intelligence;
- (NSString *)extractFolderName:(NSString *)folderName;
- (NSString *)extractParentFolderName:(NSString *)folderName;
- (BOOL)hasParentFolder:(NSString *)folderName;
- (BOOL)isFolderCollapsed:(NSString *)folderName;
- (BOOL)isFolderOrParentCollapsed:(NSString *)folderName;
- (NSArray *)parentFoldersForFeed:(NSString *)feedId;
- (NSString *)feedIdWithoutSearchQuery:(NSString *)feedId;
- (NSString *)searchQueryForFeedId:(NSString *)feedId;
- (NSString *)searchFolderForFeedId:(NSString *)feedId;
- (NSSet<NSString *> *)subscribedFeedIds;
- (NSDictionary *)feedMetadataForStory:(NSDictionary *)story preferActiveFeeds:(BOOL)preferActiveFeeds;
- (NSDictionary *)getFeedWithId:(id)feedId;
- (NSDictionary *)getFeed:(NSString *)feedId;
- (NSDictionary *)getStory:(NSString *)storyHash;

+ (void)fillGradient:(CGRect)r startColor:(UIColor *)startColor endColor:(UIColor *)endColor;
+ (UIView *)makeSimpleGradientView:(CGRect)rect startColor:(UIColor *)startColor endColor:(UIColor *)endColor;
+ (UIColor *)faviconColor:(NSString *)colorString;
+ (UIView *)makeGradientView:(CGRect)rect startColor:(NSString *)start endColor:(NSString *)end borderColor:(NSString *)borderColor;
- (UIView *)makeFeedTitleGradient:(NSDictionary *)feed withRect:(CGRect)rect;
- (UIView *)makeFeedTitle:(NSDictionary *)feed;
- (void)updateFeedDetailTitleView;
- (NSString *)folderTitle:(NSString *)folder;
- (UIImage *)folderIcon:(NSString *)folder;
- (void)saveFavicon:(UIImage *)image feedId:(NSString *)filename;
- (UIImage *)getFavicon:(NSString *)filename;
- (UIImage *)preparedFavicon:(NSString *)filename size:(CGSize)size;
- (void)prepareFavicons:(NSArray<FeedIconPreparationRequest *> *)requests;
- (NSObject *)prepareFavicons:(NSArray<FeedIconPreparationRequest *> *)requests maximumRequestCount:(NSInteger)maximumRequestCount;
- (void)cancelFaviconPreparation;
- (void)cancelFaviconPreparation:(NSObject *)preparation;
- (UIImage *)getFavicon:(NSString *)filename isSaved:(BOOL)isSaved;
/// The cached favicon for a feed, or nil when none is cached (NewsBlurAppDelegate.m remembers misses).
- (UIImage *)faviconImageForKey:(NSString *)key;

- (void)saveUserAvatar:(UIImage *)image forUserId:(NSString *)userId;
- (UIImage *)getCachedUserAvatar:(NSString *)userId;
- (UIImage *)defaultUserAvatar;


- (NSInteger)databaseSchemaVersion:(FMDatabase *)db;
- (void)createDatabaseConnection;
- (void)setupDatabase:(FMDatabase *)db force:(BOOL)force;
- (void)cancelOfflineQueue;
- (void)startOfflineQueue;
- (void)startOfflineFetchStories;
- (void)startOfflineFetchText;
- (void)startOfflineFetchImages;
- (BOOL)isReachableForOffline;
- (void)markScrollPosition:(NSInteger)position inStory:(NSDictionary *)story;
- (void)queueReadStories:(NSDictionary *)feedsStories;
- (BOOL)dequeueReadStoryHash:(NSString *)storyHash inFeed:(NSString *)storyFeedId;
- (void)flushQueuedReadStories:(BOOL)forceCheck withCallback:(void(^)(void))callback;
- (void)syncQueuedReadStories:(FMDatabase *)db withStories:(NSDictionary *)hashes withCallback:(void(^)(void))callback;
- (void)queueSavedStory:(NSDictionary *)story;
- (void)fetchTextForStory:(NSString *)storyHash inFeed:(NSString *)feedId checkCache:(BOOL)checkCache withCallback:(void(^)(NSString *))callback;
- (void)prepareActiveCachedImages:(FMDatabase *)db;
- (UIImage *)cachedImageForStoryHash:(NSString *)storyHash;
- (void)prefetchCachedStoryImageForStoryHash:(NSString *)storyHash operation:(NSOperation *)operation;
- (void)cacheStoryImage:(UIImage *)image forStoryHash:(NSString *)storyHash;
- (BOOL)cachedStoryImageForStoryHash:(NSString *)storyHash matchesSourceURLs:(NSArray *)sourceURLs;
- (NSUInteger)beginStoryImageSourceRefresh;
- (NSDictionary *)storyImageRequestForStoryHash:(NSString *)storyHash sourceURLs:(NSArray *)sourceURLs minimumRevision:(NSUInteger)minimumRevision;
- (BOOL)isCurrentStoryImageRequest:(NSDictionary *)request;
- (BOOL)cacheStoryImage:(UIImage *)image forRequest:(NSDictionary *)request;
- (void)cacheStoryImagePlaceholder:(NSString *)storyHash;
- (void)removeCachedStoryImageForStoryHash:(NSString *)storyHash;
- (void)removeAllCachedStoryImages;
- (void)cleanImageCache;
- (void)deleteAllCachedImages;
- (void)deleteAllCachedImagesWithCompletion:(void (^ _Nonnull)(BOOL success))completion NS_SWIFT_NAME(deleteAllCachedImages(completion:));

@end

@interface UnreadCounts : NSObject {
    int ps;
    int nt;
    int ng;
}

@property (readwrite) int ps;
@property (readwrite) int nt;
@property (readwrite) int ng;

- (void)addCounts:(UnreadCounts *)counts;

@end
