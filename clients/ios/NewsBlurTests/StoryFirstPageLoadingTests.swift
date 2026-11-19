import ObjectiveC.runtime
import UIKit
import UserNotifications
import WebKit
import XCTest

@testable import NewsBlur

@MainActor final class Test_StoryFirstPageLoading: XCTestCase {
#if targetEnvironment(macCatalyst)
#endif

    func test_discoveryExactStorySelectionLoadsRowsWhileReaderMessageWasVisible() async throws {
        let fixture = makeFixture()
        let presentation = try FirstPageNotificationPresentation(fixture: fixture)
        defer { presentation.close() }
        fixture.controller.usesProductionDeferredReload = true
        fixture.app.isTryFeedView = true
        fixture.app.tryFeedFeedId = "1"
        fixture.app.tryFeedStoryId = "first-page-1"
        fixture.app.inFindingStoryMode = true
        fixture.app.findingStoryStartDate = Date()
        fixture.stories.readFilterOverride = "all"
        fixture.stories.notificationStoryHash = "first-page-1"
        let selected = expectation(description: "Exact selection opens after replacing the empty reader message")
        fixture.app.storyPresented = { selected.fulfill() }
        fixture.open()
        fixture.controller.finishedAnimatingIn = true
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.controller.messageView.isHidden = false
        fixture.controller.messageLabel.text = "Select a feed or folder"
        fixture.controller.reloadImmediately()
        XCTAssertEqual(fixture.table.numberOfSections, 0)

        fixture.app.reply(to: try feedPageRequest(1, in: fixture), with: response(stories: makeStories(0..<4)))
        await settle()
        XCTAssertTrue(fixture.controller.messageView.isHidden)
        XCTAssertEqual(fixture.table.numberOfSections, 1, "The exact selection must reload after hiding the prior reader message")
        guard fixture.table.numberOfSections == 1 else { return }
        XCTAssertGreaterThan(fixture.table.numberOfRows(inSection: 0), 1)
        await fulfillment(of: [selected], timeout: 4)
        XCTAssertEqual(fixture.app.activeStory?["story_hash"] as? String, "first-page-1")
        let targetLocation = try XCTUnwrap(fixture.hashes.firstIndex(of: "first-page-1"))
        XCTAssertEqual(fixture.table.indexPathForSelectedRow, fixture.controller.indexPath(forStoryLocation: targetLocation))
    }

    func test_discoveryExactStorySelectionWaitsForTableSectionsBeforeSelecting() async throws {
        let fixture = makeFixture()
        let presentation = try FirstPageNotificationPresentation(fixture: fixture)
        defer { presentation.close() }
        let table = try XCTUnwrap(fixture.table as? FirstPageLoadingTable)
        fixture.app.isTryFeedView = true
        fixture.app.tryFeedFeedId = "1"
        fixture.app.tryFeedStoryId = "first-page-1"
        fixture.app.inFindingStoryMode = true
        fixture.app.findingStoryStartDate = Date()
        fixture.stories.readFilterOverride = "all"
        fixture.stories.notificationStoryHash = "first-page-1"
        let selected = expectation(description: "The requested story opens after the title table appears")
        fixture.app.storyPresented = { selected.fulfill() }
        fixture.open()
        fixture.controller.finishedAnimatingIn = false
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: try feedPageRequest(1, in: fixture), with: response(stories: makeStories(0..<4)))
        await settle()

        // StoryFirstPageLoadingTests.swift reproduces the reader transition before its native table has sections.
        table.forcesUnavailableSections = true
        XCTAssertEqual(table.numberOfSections, 0)
        table.recordsUnavailableSectionQueries = true
        fixture.controller.setValue(true, forKey: "isFadingTable")
        defer { fixture.controller.setValue(false, forKey: "isFadingTable") }
        fixture.controller.finishedAnimatingIn = true
        fixture.controller.testForTryFeed()
        await settle()
        XCTAssertEqual(table.unavailableSectionQueries, 0, "Initial selection must wait for a valid table section: \(table.unavailableSectionQueryStacks)")

        let retry = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            ((fixture.controller.value(forKey: "deferredLoadStoryCount") as? NSNumber)?.intValue ?? 0) >= 2
        }, object: nil)
        await fulfillment(of: [retry], timeout: 4)
        XCTAssertEqual(table.unavailableSectionQueries, 0, "Deferred selection must also check the section before querying its rows: \(table.unavailableSectionQueryStacks)")
        XCTAssertNil(fixture.app.activeStory)

        table.forcesUnavailableSections = false
        fixture.controller.setValue(false, forKey: "isFadingTable")
        fixture.controller.reloadImmediately()
        table.layoutIfNeeded()
        await fulfillment(of: [selected], timeout: 5)
        XCTAssertEqual(fixture.app.activeStory?["story_hash"] as? String, "first-page-1")
        let targetLocation = try XCTUnwrap(fixture.hashes.firstIndex(of: "first-page-1"))
        XCTAssertEqual(table.indexPathForSelectedRow, fixture.controller.indexPath(forStoryLocation: targetLocation))
    }

    func test_discoveryExactStoryLookupOpensTargetAfterEmptyOrDuplicateTitleFirstPage() async throws {
        for emptyFirstPage in [true, false] {
            let fixture = makeFixture()
            let presentation = try FirstPageNotificationPresentation(fixture: fixture)
            defer { presentation.close() }
            fixture.stories.order = "oldest"
            fixture.app.isTryFeedView = true
            fixture.app.tryFeedFeedId = "1"
            fixture.app.tryFeedStoryId = "first-page-17"
            fixture.app.inFindingStoryMode = true
            fixture.app.findingStoryStartDate = Date()
            fixture.app.tryFeedStoryTitle = nil
            fixture.stories.readFilterOverride = "all"
            fixture.stories.notificationStoryHash = "first-page-17"
            let selected = expectation(description: "The exact Discover story opens")
            fixture.app.storyPresented = { selected.fulfill() }
            fixture.open()
            fixture.controller.finishedAnimatingIn = true
            fixture.app.releaseReadFlush()
            fixture.app.releaseSavedFlush()
            await settle()
            let exact = try exactNotificationRequest("first-page-17", in: fixture)
            var duplicate = makeStories(0..<1)[0]
            duplicate["story_title"] = "A repeated daily title"
            var firstPage = response(stories: emptyFirstPage ? [] : [duplicate])
            if emptyFirstPage {
                firstPage["not_yet_fetched"] = true
                firstPage["fetched_once"] = false
            }
            fixture.app.reply(to: try feedPageRequest(1, in: fixture), with: firstPage)
            await settle()
            fixture.controller.pageFinished = true
            fixture.controller.testForTryFeed()
            XCTAssertNil(fixture.app.activeStory, "A different story with the same title cannot satisfy an exact tap")
            var target = makeStories(17..<18)[0]
            target["story_title"] = "A repeated daily title"
            target["read_status"] = 1
            fixture.app.reply(to: exact, with: response(stories: [target]))
            await fulfillment(of: [selected], timeout: 4)
            XCTAssertEqual(fixture.app.activeStory?["story_hash"] as? String, "first-page-17")
            let path = try XCTUnwrap(fixture.table.indexPathForSelectedRow)
            let targetLocation = try XCTUnwrap(fixture.hashes.firstIndex(of: "first-page-17"))
            XCTAssertEqual(path, fixture.controller.indexPath(forStoryLocation: targetLocation))
        }
    }

    func test_emptyTryFeedAutomaticallyInstafetchesWithVisibleProgress() async throws {
        let fixture = makeFixture()
        fixture.app.dictSocialProfile = ["id": "social:1", "user_id": 1, "username": "preview-test"]
        await startEmptyTryFeed(fixture)
        XCTAssertEqual(fixture.app.requests.count, 2, "An empty preview must force a feed refresh")
        XCTAssertEqual(fixture.controller.fetchingTitle, NBLocalization.text("Fetching stories from this site..."))
        XCTAssertTrue(fixture.controller.pageFetching)
        guard fixture.app.requests.count == 2 else { return }
        XCTAssertEqual(URLComponents(string: fixture.app.requests[1].url)?.path, "/reader/refresh_feed/1")
        fixture.app.reply(to: 1, with: response(stories: makeStories(20..<24)))
        await settle()
        XCTAssertEqual(fixture.hashes, (20..<24).map { "first-page-\($0)" })
        XCTAssertFalse(fixture.controller.pageFetching)
        XCTAssertNil(fixture.controller.fetchingTitle)
    }

    func test_emptyTryFeedRefreshStopsWithAClearEmptyMessageAndDoesNotRepeat() async throws {
        let fixture = makeFixture()
        await startEmptyTryFeed(fixture)
        XCTAssertEqual(fixture.app.requests.count, 2)
        guard fixture.app.requests.count == 2 else { return }
        var empty = response(stories: [])
        empty["fetched_once"] = true
        fixture.app.reply(to: 1, with: empty)
        await settle()
        XCTAssertFalse(fixture.controller.pageFetching)
        XCTAssertNil(fixture.controller.fetchingTitle)
        XCTAssertFalse(fixture.controller.messageView.isHidden)
        XCTAssertEqual(fixture.controller.messageLabel.text, "No stories are available from this site yet.")
        fixture.app.reply(to: 0, with: empty)
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 2, "An empty response must not cause repeated forced refreshes")
    }

    func test_emptyTryFeedRefreshFailureStopsWithARetryMessage() async throws {
        let fixture = makeFixture()
        await startEmptyTryFeed(fixture)
        XCTAssertEqual(fixture.app.requests.count, 2)
        guard fixture.app.requests.count == 2 else { return }
        fixture.app.fail(to: 1)
        await settle()
        XCTAssertFalse(fixture.controller.pageFetching)
        XCTAssertNil(fixture.controller.fetchingTitle)
        XCTAssertFalse(fixture.controller.messageView.isHidden)
        XCTAssertEqual(fixture.controller.messageLabel.text, "Unable to fetch stories. Pull to refresh to try again.")
    }

    func test_emptyTryFeedRefreshDiscardsLateResponsesAfterContextChanges() async throws {
        for change in ["feed", "account", "host", "generation"] {
            let fixture = makeFixture()
            await startEmptyTryFeed(fixture)
            XCTAssertEqual(fixture.app.requests.count, 2)
            guard fixture.app.requests.count == 2 else { continue }
            switch change {
            case "feed": fixture.stories.activeFeed = ["id": 2, "feed_title": "Another feed"]
            case "account": fixture.app.activeUsername = "another-account"
            case "host": fixture.app.testURL = "https://another.example.test"
            default: fixture.controller.resetFeedDetail()
            }
            fixture.app.reply(to: 1, with: response(stories: makeStories(20..<24)))
            await settle()
            XCTAssertTrue(fixture.hashes.isEmpty, "A late preview refresh cannot publish into changed \(change) state")
        }
    }

    func test_automaticInstafetchDoesNotRunForNormalFeedsOrPopulatedPreviews() async throws {
        for preview in [false, true] {
            let fixture = makeFixture()
            fixture.app.isTryFeedView = preview
            fixture.app.tryFeedFeedId = preview ? "1" : nil
            fixture.open()
            fixture.app.releaseReadFlush()
            fixture.app.releaseSavedFlush()
            await settle()
            fixture.app.reply(to: 0, with: response(stories: preview ? makeStories(0..<4) : []))
            await settle()
            XCTAssertEqual(fixture.app.requests.count, 1)
            XCTAssertNil(fixture.controller.fetchingTitle)
        }
    }

    func test_emptyTryFeedPollsPendingFetchUntilStoriesArrive() async throws {
        let fixture = makeFixture()
        fixture.controller.testRefreshPollInterval = 0.01
        await startEmptyTryFeed(fixture)
        guard fixture.app.requests.count == 2 else { return XCTFail("Missing forced refresh") }
        var pending = response(stories: [])
        pending["fetched_once"] = false
        fixture.app.reply(to: 1, with: pending)
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 3)
        XCTAssertEqual(fixture.controller.fetchingTitle, NBLocalization.text("Fetching stories from this site..."))
        guard fixture.app.requests.count == 3 else { return }
        XCTAssertEqual(URLComponents(string: fixture.app.requests[2].url)?.path, "/reader/feed/1")
        XCTAssertEqual(fixture.app.requests[2].parameters?["insta_fetch"] as? Bool, true)
        XCTAssertEqual(fixture.app.requests[2].parameters?["read_filter"] as? String, "all")
        fixture.app.reply(to: 2, with: response(stories: makeStories(20..<24)))
        await settle()
        XCTAssertEqual(fixture.hashes, (20..<24).map { "first-page-\($0)" })
        XCTAssertFalse(fixture.controller.pageFetching)
        XCTAssertNil(fixture.controller.fetchingTitle)
    }

    func test_emptyTryFeedTimeoutDiscardsLateStoriesAndAllowsManualRetry() async throws {
        let fixture = makeFixture()
        fixture.controller.testRefreshTimeout = 0.05
        await startEmptyTryFeed(fixture)
        XCTAssertFalse(fixture.controller.pageFetching)
        XCTAssertNil(fixture.controller.fetchingTitle)
        XCTAssertEqual(fixture.controller.messageLabel.text, "Unable to fetch stories. Pull to refresh to try again.")
        fixture.app.reply(to: 1, with: response(stories: makeStories(20..<24)))
        await settle()
        XCTAssertTrue(fixture.hashes.isEmpty)

        fixture.controller.testRefreshTimeout = 60
        fixture.controller.instafetchFeed()
        XCTAssertEqual(fixture.app.requests.count, 3)
        XCTAssertEqual(fixture.controller.fetchingTitle, NBLocalization.text("Fetching stories from this site..."))
        XCTAssertTrue(fixture.controller.pageFetching)
        fixture.app.reply(to: 2, with: response(stories: makeStories(30..<34)))
        await settle()
        XCTAssertEqual(fixture.hashes, (30..<34).map { "first-page-\($0)" })
    }

    func test_manualEmptyTryFeedRefreshSupersedesInitialResponse() async throws {
        let fixture = makeFixture()
        fixture.app.isTryFeedView = true
        fixture.app.tryFeedFeedId = "1"
        fixture.open()
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.controller.instafetchFeed()
        XCTAssertEqual(fixture.app.requests.count, 2)
        fixture.app.reply(to: 0, with: response(stories: makeStories(0..<4)))
        await settle()
        XCTAssertTrue(fixture.hashes.isEmpty)
        XCTAssertTrue(fixture.controller.pageFetching)
        fixture.app.reply(to: 1, with: response(stories: makeStories(20..<24)))
        await settle()
        XCTAssertEqual(fixture.hashes, (20..<24).map { "first-page-\($0)" })
        XCTAssertNil(fixture.controller.value(forKey: "firstPageLoad"), "Try previews bypass the normal first-page cache")
        fixture.controller.fetchNextPage(nil)
        guard let next = fixture.app.requests.indices.last else { return XCTFail("Missing next-page request") }
        XCTAssertEqual(URLComponents(string: fixture.app.requests[next].url)?.queryItems?.first(where: { $0.name == "page" })?.value, "2")
        fixture.app.reply(to: next, with: response(stories: makeStories(24..<28)))
        await settle()
        XCTAssertEqual(fixture.hashes, (20..<28).map { "first-page-\($0)" })
    }

    func test_cancellingEmptyTryFeedRefreshStopsLoadingAndEndsPullToRefresh() async throws {
        let fixture = makeFixture()
        await startEmptyTryFeed(fixture)
        XCTAssertTrue(fixture.controller.isAutomaticallyRefreshingTryFeed)
        XCTAssertTrue(fixture.controller.pageFetching)
        // FeedDetailObjCViewController.h exposes pull-to-refresh only outside Mac Catalyst.
        #if !targetEnvironment(macCatalyst)
        fixture.controller.refreshControl = UIRefreshControl()
        fixture.controller.refreshControl.beginRefreshing()
        #endif
        fixture.controller.instafetchFeed()
        XCTAssertEqual(fixture.app.requests.count, 2, "Refreshing during the active fetch must not duplicate it")
        fixture.controller.resetFeedDetail()
        #if !targetEnvironment(macCatalyst)
        XCTAssertFalse(fixture.controller.refreshControl.isRefreshing)
        #endif
        XCTAssertFalse(fixture.controller.isAutomaticallyRefreshingTryFeed)
        XCTAssertFalse(fixture.controller.pageFetching)
    }

    func test_emptySearchWithinTryFeedDoesNotRefreshUnfilteredStories() async throws {
        let fixture = makeFixture()
        fixture.app.isTryFeedView = true
        fixture.app.tryFeedFeedId = "1"
        fixture.open()
        fixture.stories.inSearch = true
        fixture.stories.searchQuery = "does not match any story"
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: 0, with: response(stories: []))
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 1)
        XCTAssertTrue(fixture.hashes.isEmpty)
        XCTAssertNil(fixture.controller.fetchingTitle)
    }

    func test_emptyTryFeedRefreshPreservesReadFilterAndOrder() async throws {
        let fixture = makeFixture()
        fixture.stories.readFilter = "unread"
        fixture.stories.order = "oldest"
        await startEmptyTryFeed(fixture)
        guard fixture.app.requests.count == 2 else { return XCTFail("Missing forced refresh") }
        XCTAssertEqual(fixture.app.requests[1].parameters?["read_filter"] as? String, "unread")
        XCTAssertEqual(fixture.app.requests[1].parameters?["order"] as? String, "oldest")
        fixture.stories.readFilter = "all"
        fixture.app.reply(to: 1, with: response(stories: makeStories(20..<24)))
        await settle()
        XCTAssertTrue(fixture.hashes.isEmpty, "A response for the previous filter cannot populate a changed view")
    }

    func test_emptyTryFeedRefreshIgnoresStaleFindingFlagButSkipsTargetStoryLookup() async throws {
        for hasTarget in [false, true] {
            let fixture = makeFixture()
            fixture.app.inFindingStoryMode = true
            fixture.app.tryFeedStoryId = hasTarget ? "target-story" : nil
            await startEmptyTryFeed(fixture)
            XCTAssertEqual(fixture.app.requests.count, hasTarget ? 1 : 2)
            XCTAssertEqual(fixture.controller.isAutomaticallyRefreshingTryFeed, !hasTarget)
        }
    }

    func test_explicitReselectionClearsWarmRowsUntilFreshResponseAndRetainsOfflineFallback() async throws {
        for river in [false, true] {
            for fails in [false, true] {
                let fixture = makeFixture()
                fixture.app.storyPresented = {}
                let feeds = FirstPageSelectionFeeds()
                feeds.appDelegate = fixture.app
                fixture.app.feedsViewController = feeds
                fixture.app.dictFoldersArray = NSMutableArray(array: ["dashboard", "discover_sites", "daily_briefing", "infrequent", "everything", "Sites"])
                fixture.app.dictFolders = ["Sites": [1]]
                fixture.app.riverFeeds = [1]
                fixture.stories.activeFolder = "Sites"
                if river { fixture.openRiver() } else { fixture.open() }
                fixture.app.releaseReadFlush()
                fixture.app.releaseSavedFlush()
                await settle()
                fixture.app.reply(to: 0, with: response())
                await settle()
                fixture.app.activeStory = fixture.stories.activeFeedStories.first as? [AnyHashable: Any]

                if river { feeds.selectEverything(nil) }
                else { feeds.selectFeed("1", inFolder: "Sites") }
                await settle()
                XCTAssertTrue(fixture.hashes.isEmpty, "Explicit reselection must not replay the previous list while refreshing")
                XCTAssertNil(fixture.app.activeStory)

                fixture.app.releaseReadFlush()
                fixture.app.releaseSavedFlush()
                await settle()
                if fails { fixture.app.fail(to: fixture.app.requests.count - 1) }
                else { fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: makeStories(100..<112))) }
                await settle()
                XCTAssertEqual(fixture.hashes, (fails ? 0..<12 : 100..<112).map { "first-page-\($0)" })
            }
        }
    }

    func test_automaticFirstStoryWaitsForFreshPageInsteadOfOpeningCachedArticle() async throws {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "feed_opening")
        defaults.set("story", forKey: "feed_opening")
        defer {
            if let previous { defaults.set(previous, forKey: "feed_opening") }
            else { defaults.removeObject(forKey: "feed_opening") }
        }
        let fixture = makeFixture()
        try await prime(fixture)
        var openedHashes: [String] = []
        fixture.app.storyPresented = { openedHashes.append(fixture.app.activeStory?["story_hash"] as? String ?? "missing") }
        fixture.open()
        await settle()
        XCTAssertFalse(fixture.hashes.isEmpty, "A normal warm open still shows cached rows immediately")
        fixture.controller.testForTryFeed()
        XCTAssertNil(fixture.app.activeStory, "The initial selection must wait for the refreshed first story")
        XCTAssertTrue(openedHashes.isEmpty)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: makeStories(100..<112)))
        fixture.controller.testForTryFeed()
        XCTAssertEqual(openedHashes, ["first-page-100"])
    }

    func test_failedWarmRefreshAutomaticallyOpensCachedFirstStoryForFeedsAndRivers() async throws {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "feed_opening")
        defaults.set("story", forKey: "feed_opening")
        defer {
            if let previous { defaults.set(previous, forKey: "feed_opening") }
            else { defaults.removeObject(forKey: "feed_opening") }
        }
        for river in [false, true] {
            let fixture = makeFixture()
            fixture.app.storyPresented = {}
            fixture.app.riverFeeds = [1]
            func open() {
                if river { fixture.openRiver() } else { fixture.open() }
            }
            open()
            fixture.app.releaseReadFlush()
            fixture.app.releaseSavedFlush()
            await settle()
            fixture.app.reply(to: 0, with: response())
            await settle()

            var openedHashes: [String] = []
            fixture.app.storyPresented = { openedHashes.append(fixture.app.activeStory?["story_hash"] as? String ?? "missing") }
            open()
            await settle()
            XCTAssertFalse(fixture.hashes.isEmpty)
            fixture.controller.testForTryFeed()
            XCTAssertNil(fixture.app.activeStory)
            XCTAssertTrue(openedHashes.isEmpty, "Cached articles must wait for the refresh while online")
            fixture.app.releaseReadFlush()
            fixture.app.releaseSavedFlush()
            await settle()

            // StoryFirstPageLoadingTests.swift delivers failure after the initial appearance selection attempt.
            fixture.app.fail(to: fixture.app.requests.count - 1)
            await settle()

            XCTAssertFalse(fixture.controller.isOnline)
            XCTAssertEqual(openedHashes, ["first-page-0"], "The cached first story should open when the refresh fails for river=\(river)")
        }
    }

    func test_warmOfflineFallbackOpensOnceAndPreservesManualSelection() async throws {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "feed_opening")
        defaults.set("story", forKey: "feed_opening")
        defer {
            if let previous { defaults.set(previous, forKey: "feed_opening") }
            else { defaults.removeObject(forKey: "feed_opening") }
        }
        for river in [false, true] {
            for alreadyOffline in [false, true] {
                for manuallySelected in [false, true] {
                    let fixture = makeFixture()
                    fixture.app.storyPresented = {}
                    fixture.app.riverFeeds = [1]
                    func open() {
                        if river { fixture.openRiver() } else { fixture.open() }
                    }
                    open()
                    fixture.app.releaseReadFlush()
                    fixture.app.releaseSavedFlush()
                    await settle()
                    fixture.app.reply(to: 0, with: response())
                    await settle()

                    var openedHashes: [String] = []
                    fixture.app.storyPresented = { openedHashes.append(fixture.app.activeStory?["story_hash"] as? String ?? "missing") }
                    open()
                    await settle()
                    XCTAssertFalse(fixture.hashes.isEmpty)
                    fixture.controller.testForTryFeed()
                    XCTAssertTrue(openedHashes.isEmpty)
                    if manuallySelected {
                        fixture.app.activeStory = fixture.stories.activeFeedStories[3] as? [AnyHashable: Any]
                    }
                    if alreadyOffline { fixture.controller.isOnline = false }
                    fixture.app.releaseReadFlush()
                    fixture.app.releaseSavedFlush()
                    await settle()
                    if !alreadyOffline {
                        fixture.app.fail(to: fixture.app.requests.count - 1)
                        await settle()
                    }

                    let context = "river=\(river), alreadyOffline=\(alreadyOffline), manuallySelected=\(manuallySelected)"
                    XCTAssertEqual(openedHashes, manuallySelected ? [] : ["first-page-0"], context)
                    XCTAssertEqual(fixture.app.activeStory?["story_hash"] as? String,
                                   manuallySelected ? "first-page-3" : "first-page-0", context)
                    fixture.controller.testForTryFeed()
                    XCTAssertEqual(openedHashes, manuallySelected ? [] : ["first-page-0"], "Appearance must not reopen a selected story: \(context)")
                }
            }
        }
    }

    func test_switchingAwayThenBackStillUsesWarmFirstPage() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        let feeds = FirstPageSelectionFeeds()
        feeds.appDelegate = fixture.app
        fixture.app.feedsViewController = feeds
        fixture.app.dictFoldersArray = NSMutableArray(array: ["Sites"])
        fixture.app.dictFolders = ["Sites": [1, 2]]
        fixture.app.dictFeeds["2"] = ["id": 2, "feed_title": "Second feed", "active": 1]
        fixture.stories.activeFolder = "Sites"
        feeds.selectFeed("2", inFolder: "Sites")
        await settle()
        XCTAssertTrue(fixture.hashes.isEmpty)
        feeds.selectFeed("1", inFolder: "Sites")
        await settle()
        XCTAssertEqual(fixture.hashes, (0..<12).map { "first-page-\($0)" })
        XCTAssertNil(fixture.app.activeStory)
    }

    func test_focusedRiverContinuesPagingWithoutAScrollWhenFirstPageDoesNotFillTheList() async throws {
        let fixture = makeFixture()
        fixture.app.selectedIntelligence = 1
        fixture.controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        fixture.table.frame = fixture.controller.view.bounds
        let previousWindow = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow)
        let window = UIWindow(frame: fixture.controller.view.bounds)
        window.rootViewController = fixture.controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previousWindow?.makeKeyAndVisible() }
        fixture.controller.finishedAnimatingIn = true
        fixture.openRiver()
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 1)
        var firstPage = makeStories(0..<12)
        for index in 0..<3 { firstPage[index]["intelligence"] = ["feed": 1] }
        fixture.app.reply(to: 0, with: response(stories: firstPage))
        fixture.table.layoutIfNeeded()
        await settle()
        XCTAssertEqual(fixture.stories.storyLocationsCount, 3)
        // StoryFirstPageLoadingTests.swift reproduces ClayPad startup with Focus hiding nine of twelve rows.
        XCTAssertEqual(fixture.app.requests.count, 2, "An underfilled Focus list must fetch page two without a user scroll")
        guard fixture.app.requests.count == 2 else { return }
        XCTAssertEqual(query("page", in: fixture.app.requests[1].url), "2")
        var secondPage = makeStories(12..<24)
        secondPage[0]["intelligence"] = ["feed": 1]
        fixture.app.reply(to: 1, with: response(stories: secondPage))
        await settle()
        XCTAssertEqual(fixture.stories.storyLocationsCount, 4)
        XCTAssertEqual(fixture.app.requests.count, 3, "A partially filtered page must continue fetching while the list is underfilled")
        guard fixture.app.requests.count == 3 else { return }
        fixture.app.reply(to: 2, with: response(stories: makeStories(24..<36)))
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 4, "A completely filtered page must continue fetching")
        guard fixture.app.requests.count == 4 else { return }
        fixture.app.reply(to: 3, with: response(stories: []))
        await settle()
        XCTAssertTrue(fixture.controller.pageFinished)
        XCTAssertFalse(fixture.controller.pageFetching)
        XCTAssertEqual(fixture.app.requests.count, 4, "An exhausted river must stop fetching and stop its loading indicator")
    }

    func test_nextReadRefreshKeepsPartlyVisibleTitleRevealContinuous() async throws {
        for estimate: CGFloat in [0, 44] {
            let fixture = makeFixture()
            let presentation = try FirstPageNotificationPresentation(fixture: fixture)
            defer { presentation.close() }
            fixture.controller.testRowHeight = 200
            fixture.table.estimatedRowHeight = estimate
            fixture.table.contentInsetAdjustmentBehavior = .never
            fixture.controller.view.frame.size.height = 700
            fixture.table.frame = fixture.controller.view.bounds
            try await prime(fixture, stories: makeStories(0..<30))
            fixture.controller.pageFinished = true
            fixture.table.layoutIfNeeded()
            fixture.app.activeStory = fixture.stories.activeFeedStories[2] as? [AnyHashable: Any]
            fixture.table.selectRow(at: IndexPath(row: 2, section: 0), animated: false, scrollPosition: .none)
            let target = IndexPath(row: 3, section: 0)
            XCTAssertTrue(fixture.table.bounds.intersects(fixture.table.rectForRow(at: target)))
            XCTAssertFalse(fixture.table.bounds.contains(fixture.table.rectForRow(at: target)))
            let before = XCTAttachment(image: UIGraphicsImageRenderer(bounds: fixture.table.bounds).image { context in
                fixture.table.layer.render(in: context.cgContext)
            })
            before.name = "Next reveal before: fourth title partly visible, estimate \(estimate)"
            before.lifetime = .keepAlways
            add(before)
            let table = try XCTUnwrap(fixture.table as? FirstPageLoadingTable)
            table.rowReloads = 0
            let recorder = NextTitleRevealRecorder(table: table)
            let ready = expectation(description: "The title table has stable native presentation frames")
            let finished = expectation(description: "UIKit completes the Next title reveal")
            fixture.controller.scrollAnimationFinished = {
                recorder.finishAfterPresentation { finished.fulfill() }
            }
            // StoryFirstPageLoadingTests.swift exercises the real list callbacks, in the
            // same order as StoryPagesObjCViewController.m's Next/page-swipe completion.
            recorder.start {
                ready.fulfill()
                fixture.app.activeStory = fixture.stories.activeFeedStories[3] as? [AnyHashable: Any]
                fixture.controller.changeActiveFeedDetailRow()
                fixture.app.recentlyReadStories["first-page-3"] = true
                fixture.controller.redrawUnreadStory()
            }
            await fulfillment(of: [ready, finished], timeout: 5)
            fixture.controller.scrollAnimationFinished = nil
            recorder.stop()
            let samples = recorder.offsets
            print("NEXT_TITLE_REVEAL estimate=\(estimate) reloads=\(table.rowReloads) offsets=\(samples)")
            XCTAssertEqual(table.rowReloads, 0, "Marking the Next story read must not rebuild rows during its reveal animation")
            XCTAssertEqual(table.indexPathForSelectedRow, target)
            XCTAssertGreaterThan(samples.max() ?? 0, 0)
            // StoryFirstPageLoadingTests.swift checks actual interpolation, independent of the CI runner's frame rate.
            let start = try XCTUnwrap(samples.first)
            let end = try XCTUnwrap(samples.last)
            XCTAssertEqual(end, table.contentOffset.y, accuracy: 0.5, "The final recorded offset must be a displayed frame")
            XCTAssertTrue(samples.contains { $0 > start + 0.5 && $0 < end - 0.5 },
                          "The title must visibly scroll through intermediate positions instead of jumping")
            XCTAssertTrue(table.bounds.contains(table.rectForRow(at: target)), "The completed reveal must fully show the next title")
            for (earlier, later) in zip(samples, samples.dropFirst()) {
                XCTAssertGreaterThanOrEqual(later + 0.5, earlier, "The reveal must not jump backwards while moving to the next title")
            }
        }
    }

    func test_reopenedFeedShowsCachedRowsBeforeQueuedReadAndSaveFlushesFinish() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.app.requests.removeAll()

        fixture.open()
        await settle()

        XCTAssertEqual(fixture.hashes, (0..<12).map { "first-page-\($0)" })
        XCTAssertEqual(fixture.app.readFlushes.count, 1)
        XCTAssertTrue(fixture.app.savedFlushes.isEmpty)
        XCTAssertTrue(fixture.app.requests.isEmpty)
        XCTAssertFalse(fixture.controller.pageFetching)
        XCTAssertFalse(fixture.controller.pageFinished)
        XCTAssertTrue(fixture.controller.isOnline)
        XCTAssertEqual(fixture.stories.feedPage, 1)

        fixture.controller.fetchNextPage(nil)
        fixture.controller.fetchFeedDetail(2, withCallback: nil)
        fixture.controller.checkScroll()
        XCTAssertTrue(fixture.app.requests.isEmpty, "Provisional rows must not start page two before authoritative page one")

        fixture.app.releaseReadFlush()
        XCTAssertEqual(fixture.app.savedFlushes.count, 1)
        XCTAssertTrue(fixture.app.requests.isEmpty)
        fixture.app.releaseSavedFlush()
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 1)
        XCTAssertTrue(fixture.app.requests.first?.url.contains("page=1&") == true)
    }

    func test_emptyCachedFirstPageStillRequestsAuthoritativePageOne() async throws {
        let fixture = makeFixture()
        try await prime(fixture, stories: [])
        fixture.app.requests.removeAll()
        fixture.open()
        await settle()
        XCTAssertTrue(fixture.hashes.isEmpty)
        XCTAssertFalse(fixture.controller.pageFinished)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 1)
        XCTAssertTrue(fixture.app.requests.first?.url.contains("page=1&") == true)
    }

    func test_laterPagesDoNotReplaceCachedFirstPage() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.controller.fetchNextPage(nil)
        fixture.app.reply(to: 1, with: response(stories: makeStories(12..<24)))
        XCTAssertEqual(fixture.hashes.count, 24)
        fixture.open()
        await settle()
        XCTAssertEqual(fixture.hashes, (0..<12).map { "first-page-\($0)" })
    }

    func test_accountHostAndReadFilterCannotReuseAnotherSnapshot() async throws {
        for changedKey in ["account", "host", "filter", "order"] {
            let fixture = makeFixture()
            try await prime(fixture)
            if changedKey == "account" { fixture.app.activeUsername = "different-" + UUID().uuidString }
            if changedKey == "host" { fixture.app.testURL = "https://other.example.test" }
            if changedKey == "filter" { fixture.stories.readFilter = "unread" }
            if changedKey == "order" { fixture.stories.order = "oldest" }
            fixture.open()
            await settle()
            XCTAssertTrue(fixture.hashes.isEmpty, changedKey)
        }
    }

    func test_oldQueuedFlushCannotLaunchARequestForNewNavigation() async throws {
        let fixture = makeFixture()
        fixture.open()
        fixture.stories.activeFeed = ["id": 2, "feed_title": "Second feed"]
        fixture.open()
        fixture.app.releaseReadFlush()
        await settle()
        XCTAssertTrue(fixture.app.savedFlushes.isEmpty)
        XCTAssertTrue(fixture.app.requests.isEmpty)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 1)
        XCTAssertTrue(fixture.app.requests.first?.url.contains("/feed/2/") == true)
    }

    func test_lateAuthoritativeResponseCannotReplaceNewFeedOrAccount() async throws {
        for changeAccount in [false, true] {
            let fixture = makeFixture()
            fixture.open()
            fixture.app.releaseReadFlush()
            fixture.app.releaseSavedFlush()
            await settle()
            if changeAccount { fixture.app.activeUsername = "different-" + UUID().uuidString }
            fixture.stories.activeFeed = ["id": 2, "feed_title": "Second feed"]
            fixture.open()
            fixture.app.reply(to: 0, with: response())
            await settle()
            XCTAssertTrue(fixture.hashes.isEmpty)
        }
    }

    func test_localReadAndSaveWhileFlushingSurviveOlderServerResponse() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        let story = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        fixture.stories.markStoryRead(story, feed: nil)
        let readStory = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        _ = fixture.stories.markStory(readStory, asSaved: true)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response())
        await settle()
        let refreshed = try XCTUnwrap((fixture.stories.activeFeedStories as? [[String: Any]])?.first)
        XCTAssertEqual(refreshed["read_status"] as? Int, 1)
        XCTAssertEqual(refreshed["starred"] as? Bool, true)
        XCTAssertNotNil(refreshed["starred_date"])
    }

    func test_localUnreadAndUnsavePreserveReversalAndRemovedDate() async throws {
        let fixture = makeFixture()
        var stories = makeStories(0..<12)
        stories[0]["read_status"] = 1
        stories[0]["starred"] = true
        stories[0]["starred_date"] = "Yesterday"
        try await prime(fixture, stories: stories)
        fixture.open()
        await settle()
        let story = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        fixture.stories.markStoryUnread(story, feed: nil)
        let unreadStory = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        _ = fixture.stories.markStory(unreadStory, asSaved: false)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: stories))
        await settle()
        let refreshed = try XCTUnwrap((fixture.stories.activeFeedStories as? [[String: Any]])?.first)
        XCTAssertEqual(refreshed["read_status"] as? Int, 0)
        XCTAssertEqual(refreshed["starred"] as? Bool, false)
        XCTAssertNil(refreshed["starred_date"])
    }

    func test_provisionalReadStateDoesNotTrustUnownedGlobalReadTables() async throws {
        let fixture = makeFixture()
        var stories = makeStories(0..<12)
        stories[0]["read_status"] = 1
        try await prime(fixture, stories: stories)
        fixture.app.unreadStoryHashes["first-page-0"] = true
        fixture.app.recentlyReadStories["first-page-1"] = true
        let cacheLoaded = expectation(description: "Cached stories are published before checking provisional read ownership")
        fixture.controller.cacheLookupFinished = { cacheLoaded.fulfill() }
        fixture.open()
        await fulfillment(of: [cacheLoaded], timeout: 5)
        fixture.controller.cacheLookupFinished = nil
        let first = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        let second = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.dropFirst().first)
        XCTAssertFalse(fixture.stories.isStoryUnread(first))
        XCTAssertTrue(fixture.stories.isStoryUnread(second))
    }

    func test_cachedUnreadTitlesAdoptServerReadArtworkWithoutMarkingStoriesRead() async throws {
        try await assertCacheReadReconciliationWithoutReading(serverReadStatus: 1)
    }

    func test_cachedUnreadTitlesStayUnreadWhenServerStillReportsUnread() async throws {
        try await assertCacheReadReconciliationWithoutReading(serverReadStatus: 0)
    }

    private func assertCacheReadReconciliationWithoutReading(serverReadStatus: Int) async throws {
        let fixture = makeFixture()
        let cachedStories = makeStories(0..<12)
        try await prime(fixture, stories: cachedStories)
        let cacheLoaded = expectation(description: "Warm feed publishes its provisional unread titles")
        fixture.controller.cacheLookupFinished = { cacheLoaded.fulfill() }
        fixture.open()
        await fulfillment(of: [cacheLoaded], timeout: SimulatorTestTiming.realWorkTimeout)
        fixture.controller.cacheLookupFinished = nil

        let cached = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        XCTAssertEqual(cached["_nb_provisional_read_state"] as? Bool, true)
        XCTAssertTrue(fixture.stories.isStoryUnread(cached))
        let cachedPath = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 0))
        let cachedCell = try XCTUnwrap(fixture.controller.tableView(fixture.table, cellForRowAt: cachedPath) as? FeedDetailTableCell)
        XCTAssertFalse(cachedCell.isRead)

        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        var authoritativeStories = cachedStories
        authoritativeStories[0]["read_status"] = serverReadStatus
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: authoritativeStories))
        await settle()
        fixture.table.layoutIfNeeded()
        fixture.controller.checkScroll()

        let refreshed = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        XCTAssertNil(refreshed["_nb_provisional_read_state"])
        XCTAssertEqual(fixture.stories.isStoryUnread(refreshed), serverReadStatus == 0)
        let refreshedPath = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 0))
        let refreshedCell = try XCTUnwrap(fixture.controller.tableView(fixture.table, cellForRowAt: refreshedPath) as? FeedDetailTableCell)
        XCTAssertEqual(refreshedCell.isRead, serverReadStatus == 1,
                       "StoryFirstPageLoadingTests.swift distinguishes authoritative read artwork from a new read action.")
        XCTAssertTrue(fixture.controller.markReadAttempts.isEmpty, "Opening and reconciling a feed cannot attempt to mark a story read")
        XCTAssertTrue(fixture.app.postURLs.filter { $0.contains("mark_story_hashes_as_read") }.isEmpty)
        XCTAssertEqual(fixture.app.recentlyReadStories.count, 0)
        XCTAssertNil(fixture.app.activeStory)
        XCTAssertNil(fixture.table.indexPathForSelectedRow)
    }

    func test_authoritativeInsertionPreservesVisibleStoryPixelOffsetAndSelection() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        let path = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 4))
        fixture.table.contentOffset.y = fixture.table.rectForRow(at: path).minY + 13
        fixture.table.selectRow(at: path, animated: false, scrollPosition: .none)
        fixture.controller.markedHashes.removeAll()
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: makeStories(100..<103) + makeStories(0..<12)))
        await settle()

        let moved = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 7))
        XCTAssertEqual(fixture.table.contentOffset.y - fixture.table.rectForRow(at: moved).minY, 13, accuracy: 0.5)
        XCTAssertEqual(fixture.table.indexPathForSelectedRow, moved)
        XCTAssertTrue(fixture.controller.markedHashes.isEmpty, "Programmatic restoration must not mark passed rows read")
    }

    func test_networkRefreshFailureKeepsCachedRowsAndRestoresNormalPagingFlags() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.fail(to: fixture.app.requests.count - 1)
        await settle()
        XCTAssertEqual(fixture.hashes.count, 12)
        XCTAssertFalse(fixture.controller.pageFetching)
        XCTAssertFalse(fixture.controller.isOnline)
        XCTAssertFalse(fixture.controller.value(forKey: "restoringFirstPageViewport") as? Bool ?? true)
        fixture.controller.resetFeedDetail()
        XCTAssertFalse(fixture.controller.value(forKey: "restoringFirstPageViewport") as? Bool ?? true)
        XCTAssertNil(fixture.controller.value(forKey: "firstPageLoad"))
    }

    func test_authoritativeResponseRemovesProvisionalReadResolver() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response())
        fixture.app.recentlyReadStories["first-page-0"] = true
        let story = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        XCTAssertNil(story["_nb_provisional_read_state"])
        XCTAssertFalse(fixture.stories.isStoryUnread(story), "Authoritative rows resume the existing global read resolver")
    }

    func test_incomingSourceResponseCannotReplaceDuoFullscreenRetainedArticle() async throws {
        let fixture = makeFixture()
        let detail = DetailViewController()
        detail.appDelegate = fixture.app
        detail.isCompact = false
        if #available(iOS 17.0, *) { detail.traitOverrides.verticalSizeClass = .regular }
        fixture.app.detailViewController = detail
        let pages = FirstPageLoadingPages()
        pages.appDelegate = fixture.app
        pages.currentPage = StoryDetailViewController()
        pages.nextPage = StoryDetailViewController()
        pages.previousPage = StoryDetailViewController()
        fixture.app.testPages = pages
        defer {
            fixture.app.testPages = nil
            fixture.app.detailViewController = nil
        }
        fixture.open()
        fixture.app.activeStory = ["story_hash": "outgoing-source:2", "story_feed_id": 99]
        pages.currentPage.activeStoryId = "outgoing-source:2"
        pages.currentPage.pageIndex = 2
        // StoryFirstPageLoadingTests.swift feeds the same retained state created by StoryPages.resetPages during Duo source browsing.
        pages.setValue(true, forKey: "retainsDuoSourceArticle")
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: try feedPageRequest(1, in: fixture), with: response(stories: makeStories(0..<4)))
        await settle()
        XCTAssertEqual(fixture.hashes, ["first-page-0", "first-page-1", "first-page-2", "first-page-3"])
        XCTAssertEqual(fixture.app.activeStory?["story_hash"] as? String, "outgoing-source:2")
        XCTAssertEqual(pages.currentPage.activeStoryId, "outgoing-source:2")
        XCTAssertEqual(pages.currentPage.pageIndex, 2)
        XCTAssertTrue(pages.pageChanges.isEmpty, "Loading titles must not select the new source's first article")
        XCTAssertEqual(pages.advances, 0, "Only an explicit reader navigation action may leave the retained article")
    }

    func test_explicitNextUnreadCompletesAfterPagingWhileDuoRetainsAnotherSourcesArticle() async throws {
        for explicitNext in [false, true] {
            let fixture = makeFixture()
            fixture.app.dictUnreadCounts = ["1": ["nt": 1, "ps": 0, "ng": 0]]
            let detail = DetailViewController()
            detail.appDelegate = fixture.app
            detail.isCompact = false
            if #available(iOS 17.0, *) { detail.traitOverrides.verticalSizeClass = .regular }
            fixture.app.detailViewController = detail
            let pages = FirstPageLoadingPages()
            pages.appDelegate = fixture.app
            pages.usesProductionUnreadAdvance = true
            pages.currentPage = StoryDetailViewController()
            pages.nextPage = StoryDetailViewController()
            pages.previousPage = StoryDetailViewController()
            fixture.app.testPages = pages
            defer {
                fixture.app.testPages = nil
                fixture.app.detailViewController = nil
            }
            fixture.open()
            fixture.app.activeStory = ["story_hash": "outgoing-source:2", "story_feed_id": 99]
            pages.currentPage.activeStoryId = "outgoing-source:2"
            pages.currentPage.pageIndex = 2
            pages.setValue(true, forKey: "retainsDuoSourceArticle")
            fixture.app.releaseReadFlush()
            fixture.app.releaseSavedFlush()
            await settle()
            let readStories = makeStories(0..<4).map { story -> [String: Any] in
                var readStory = story
                readStory["read_status"] = 1
                return readStory
            }
            fixture.app.reply(to: try feedPageRequest(1, in: fixture), with: response(stories: readStories))
            await settle()
            XCTAssertEqual(fixture.stories.locationOfNextUnreadStory(), -1)
            XCTAssertEqual(fixture.app.unreadCount(), 1)
            XCTAssertFalse(fixture.controller.pageFinished)
            XCTAssertTrue(pages.pageChanges.isEmpty, "Loading the new source must retain the displayed article")
            XCTAssertEqual(pages.advances, 0)

            // StoryFirstPageLoadingTests.swift exercises the real Next action and its real page-2 callback;
            // ordinary title-list pagination must not replace the retained article without that action.
            if explicitNext { pages.doNextUnreadStory(nil) }
            else { fixture.controller.fetchNextPage(nil) }
            XCTAssertEqual(pages.waitingForNextUnreadFromServer, explicitNext)
            fixture.app.reply(to: try feedPageRequest(2, in: fixture), with: response(stories: makeStories(4..<5)))
            await settle()

            XCTAssertEqual(fixture.hashes, (0..<5).map { "first-page-\($0)" })
            XCTAssertEqual(pages.pageChanges, explicitNext ? [4] : [], "Only the pending explicit Next action may select the newly arrived unread story")
            XCTAssertEqual(pages.advances, explicitNext ? 1 : 0)
            XCTAssertFalse(pages.waitingForNextUnreadFromServer, "An unread response must complete the pending navigation")
        }
    }

    func test_switchingSourcesCancelsPendingNextUnreadWhileDuoRetainsArticle() async throws {
        let fixture = makeFixture()
        fixture.app.dictUnreadCounts = ["1": ["nt": 1, "ps": 0, "ng": 0], "2": ["nt": 1, "ps": 0, "ng": 0]]
        let detail = DetailViewController()
        detail.appDelegate = fixture.app
        detail.isCompact = false
        if #available(iOS 17.0, *) { detail.traitOverrides.verticalSizeClass = .regular }
        fixture.app.detailViewController = detail
        let pages = FirstPageLoadingPages()
        pages.appDelegate = fixture.app
        pages.usesProductionUnreadAdvance = true
        pages.loadingIndicator = UIActivityIndicatorView(style: .medium)
        pages.buttonNext = UIButton(type: .system)
        pages.circularProgressView = THCircularProgressView()
        pages.currentPage = StoryDetailViewController()
        pages.nextPage = StoryDetailViewController()
        pages.previousPage = StoryDetailViewController()
        fixture.app.testPages = pages
        defer {
            fixture.app.testPages = nil
            fixture.app.detailViewController = nil
        }
        fixture.open()
        let retainedStory: [AnyHashable: Any] = ["story_hash": "outgoing-source:2", "story_feed_id": 99]
        fixture.app.activeStory = retainedStory
        pages.currentPage.activeStoryId = "outgoing-source:2"
        pages.currentPage.pageIndex = 2
        pages.setValue(true, forKey: "retainsDuoSourceArticle")
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        var readStory = makeStories(0..<1)[0]
        readStory["read_status"] = 1
        fixture.app.reply(to: try feedPageRequest(1, in: fixture), with: response(stories: [readStory]))
        await settle()
        pages.doNextUnreadStory(nil)
        let stalePageRequest = try feedPageRequest(2, in: fixture)
        XCTAssertTrue(pages.waitingForNextUnreadFromServer)
        XCTAssertTrue(pages.loadingIndicator.isAnimating)
        XCTAssertFalse(pages.buttonNext.isEnabled)
        XCTAssertTrue(pages.circularProgressView.isHidden)

        fixture.stories.activeFeed = ["id": 2, "feed_title": "Another feed", "active": 1]
        fixture.open()
        // StoryFirstPageLoadingTests.swift restores the mounted article as the production Duo resetPages path does;
        // the real feed reset and network generation handling remain active in this fixture.
        fixture.app.activeStory = retainedStory
        XCTAssertFalse(pages.waitingForNextUnreadFromServer, "Changing source must cancel the previous source's pending Next action")
        XCTAssertFalse(pages.loadingIndicator.isAnimating, "Source changes must stop the canceled Next request's spinner")
        XCTAssertTrue(pages.buttonNext.isEnabled)
        XCTAssertFalse(pages.circularProgressView.isHidden)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: stalePageRequest, with: response(stories: makeStories(1..<2)))
        XCTAssertTrue(fixture.hashes.isEmpty, "The prior source's late pagination cannot populate the new source")
        let sourceRequest = try XCTUnwrap(fixture.app.requests.firstIndex {
            URLComponents(string: $0.url)?.path == "/reader/feed/2/" && query("page", in: $0.url) == "1"
        })
        var unreadStory = makeStories(10..<11)[0]
        unreadStory["story_feed_id"] = 2
        var newSourceResponse = response(stories: [unreadStory])
        newSourceResponse["feed_id"] = 2
        fixture.app.reply(to: sourceRequest, with: newSourceResponse)
        await settle()

        XCTAssertEqual(fixture.hashes, ["first-page-10"])
        XCTAssertEqual(fixture.app.activeStory?["story_hash"] as? String, "outgoing-source:2")
        XCTAssertTrue(pages.pageChanges.isEmpty, "The prior source's Next action cannot select an unread article from the new source")
        XCTAssertEqual(pages.advances, 0)
    }

    func test_cachedArticleMissingFromUnreadRefreshStaysOpenUntilExplicitNextOrPrevious() async throws {
        for direction in [-1, 1] {
            let fixture = makeFixture()
            fixture.stories.readFilter = "unread"
            try await prime(fixture)
            let cacheLoaded = expectation(description: "The reopened feed applies its cached first page")
            fixture.controller.cacheLookupFinished = { cacheLoaded.fulfill() }
            fixture.open()
            // StoryFirstPageLoadingTests.swift waits for the utility-queue cache callback, not a main-queue delay.
            await fulfillment(of: [cacheLoaded], timeout: 5)
            fixture.controller.cacheLookupFinished = nil
            let cached = try XCTUnwrap(fixture.stories.activeFeedStories as? [[AnyHashable: Any]])
            fixture.app.activeStory = cached[5]
            let pages = FirstPageLoadingPages()
            pages.appDelegate = fixture.app
            pages.currentPage = StoryDetailViewController()
            pages.currentPage.pageIndex = 5
            fixture.app.testPages = pages
            fixture.app.releaseReadFlush()
            fixture.app.releaseSavedFlush()
            await settle()
            let remaining = makeStories(0..<12).filter { $0["story_hash"] as? String != "first-page-5" }
            fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: remaining))
            await settle()
            XCTAssertEqual(fixture.app.activeStory["story_hash"] as? String, "first-page-5")
            XCTAssertEqual(pages.currentPage.pageIndex, 5)
            XCTAssertTrue(pages.pageChanges.isEmpty)
            XCTAssertTrue(fixture.controller.hasRetainedFirstPageStory())
            pages.setStoryFromScroll(true)
            XCTAssertTrue(pages.pageChanges.isEmpty)
            let action = NSSelectorFromString(direction > 0 ? "changeToNextPage:" : "changeToPreviousPage:")
            pages.perform(action, with: nil)
            XCTAssertEqual(pages.pageChanges, [direction > 0 ? 5 : 4])
            XCTAssertFalse(fixture.controller.hasRetainedFirstPageStory())
        }
    }

    func test_retainedArticleWithNoSurvivingNeighborsClampsAndFeedNavigationClearsGuard() async throws {
        for navigateFeed in [false, true] {
            let fixture = makeFixture()
            try await prime(fixture)
            fixture.open()
            await settle()
            fixture.app.activeStory = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?[9])
            let pages = FirstPageLoadingPages()
            pages.appDelegate = fixture.app
            pages.currentPage = StoryDetailViewController()
            pages.currentPage.pageIndex = 9
            fixture.app.testPages = pages
            fixture.app.releaseReadFlush()
            fixture.app.releaseSavedFlush()
            await settle()
            fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: makeStories(100..<102)))
            await settle()
            XCTAssertEqual(pages.currentPage.pageIndex, 9)
            XCTAssertTrue(fixture.controller.hasRetainedFirstPageStory())
            if navigateFeed {
                fixture.open()
                XCTAssertFalse(fixture.controller.hasRetainedFirstPageStory())
            } else {
                pages.perform(NSSelectorFromString("changeToNextPage:"), with: nil)
                XCTAssertEqual(pages.pageChanges, [1])
            }
        }
    }

    func test_provisionalPresentationDoesNotReplaceGlobalFeedMetadataOrProfile() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.app.dictActiveFeeds = ["sentinel": ["id": "sentinel"]]
        fixture.app.dictSocialProfile = ["id": 99, "username": "owner"]
        fixture.open()
        let recentlyRead = fixture.app.recentlyReadFeeds
        await settle()
        XCTAssertEqual(fixture.hashes.count, 12)
        XCTAssertEqual(fixture.app.dictActiveFeeds.count, 1)
        XCTAssertNotNil(fixture.app.dictActiveFeeds["sentinel"])
        XCTAssertEqual(fixture.app.dictSocialProfile["id"] as? Int, 99)
        XCTAssertTrue(fixture.app.recentlyReadFeeds === recentlyRead)
    }

    func test_lateSnapshotCannotReplaceAnAuthoritativeResponseOrNewNavigation() async throws {
        for change in ["response", "navigation", "account", "filter"] {
            let fixture = makeFixture()
            try await prime(fixture)
            fixture.controller.holdCache = true
            fixture.open()
            await settle()
            XCTAssertEqual(fixture.controller.heldCache.count, 1)
            if change == "response" {
                fixture.app.releaseReadFlush()
                fixture.app.releaseSavedFlush()
                await settle()
                fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: makeStories(100..<112)))
            } else if change == "navigation" {
                fixture.stories.activeFeed = ["id": 2]
                fixture.open()
            } else if change == "account" { fixture.app.activeUsername = "other" }
            else { fixture.stories.readFilter = "unread" }
            fixture.controller.releaseCache()
            await settle()
            XCTAssertEqual(fixture.hashes, change == "response" ? (100..<112).map { "first-page-\($0)" } : [])
        }
    }

    func test_trainingChangeWhileSnapshotLookupWaitsIsPreserved() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.stories.activeClassifiers = NSMutableDictionary()
        fixture.controller.holdCache = true
        fixture.open()
        await settle()
        fixture.stories.activeClassifiers["1"] = ["feeds": ["1": 1]]
        fixture.controller.releaseCache()
        await settle()
        let classifier = fixture.stories.activeClassifiers["1"] as? [String: Any]
        XCTAssertEqual((classifier?["feeds"] as? [String: Int])?["1"], 1)
    }

    func test_knownOfflineAndCancelledPageOneReleasePaginationGate() async throws {
        for outcome in ["offline", "cancel", "wrong feed"] {
            let fixture = makeFixture()
            try await prime(fixture)
            fixture.open()
            await settle()
            if outcome == "offline" { fixture.controller.isOnline = false }
            fixture.app.releaseReadFlush()
            fixture.app.releaseSavedFlush()
            await settle()
            if outcome == "cancel" { fixture.app.fail(to: fixture.app.requests.count - 1, code: NSURLErrorCancelled) }
            if outcome == "wrong feed" {
                var wrong = response()
                wrong["feed_id"] = 2
                fixture.app.reply(to: fixture.app.requests.count - 1, with: wrong)
            }
            let load = try XCTUnwrap(fixture.controller.value(forKey: "firstPageLoad") as? StoryFirstPageLoad)
            XCTAssertFalse(load.pending, outcome)
            XCTAssertFalse(fixture.controller.pageFetching, outcome)
            XCTAssertEqual(fixture.hashes.count, 12, outcome)
        }
    }

    func test_sameOpenArticleMovesWithoutReplacingItsPageOrAdvancingUnread() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        fixture.app.activeStory = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?[5])
        let pages = FirstPageLoadingPages()
        pages.appDelegate = fixture.app
        let page = FirstPageLoadingStoryPage()
        page.pageIndex = 5
        pages.currentPage = page
        pages.scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        pages.scrollView.contentSize = CGSize(width: 390 * 15, height: 844 * 15)
        fixture.app.testPages = pages
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: makeStories(100..<103) + makeStories(0..<12)))
        await settle()
        XCTAssertTrue(pages.currentPage === page)
        XCTAssertEqual(page.pageIndex, 8)
        if pages.isHorizontal {
            XCTAssertEqual(page.view.frame.minX, 390 * 8, accuracy: 0.5)
            XCTAssertEqual(pages.scrollView.contentOffset.x, 390 * 8, accuracy: 0.5)
        } else {
            XCTAssertEqual(page.view.frame.minY, 844 * 8, accuracy: 0.5)
            XCTAssertEqual(pages.scrollView.contentOffset.y, 844 * 8, accuracy: 0.5)
        }
        XCTAssertEqual(fixture.app.activeStory["story_hash"] as? String, "first-page-5")
        XCTAssertTrue(pages.pageChanges.isEmpty)
        XCTAssertEqual(pages.advances, 0)
    }

    func test_forcedSavedTagEditDuringRefreshKeepsAddedAndRemovedTags() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        var edited = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        edited["user_tags"] = ["added"]
        _ = fixture.stories.markStory(edited, asSaved: true, forceUpdate: true)
        edited["user_tags"] = [] as [String]
        _ = fixture.stories.markStory(edited, asSaved: true, forceUpdate: true)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response())
        let refreshed = try XCTUnwrap((fixture.stories.activeFeedStories as? [[String: Any]])?.first)
        XCTAssertEqual(refreshed["user_tags"] as? [String], [])
        XCTAssertEqual(refreshed["starred"] as? Bool, true)
    }

    func test_folderReopenShowsSnapshotBeforeQueuesAndPreservesEightHundredFeedLimit() async throws {
        let fixture = makeFixture()
        fixture.app.riverFeeds = (1...805).map { NSNumber(value: $0) }
        fixture.openRiver()
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 1)
        let firstURL = try XCTUnwrap(fixture.app.requests.first?.url)
        XCTAssertTrue(firstURL.contains("&f=800&page=1"))
        XCTAssertFalse(firstURL.contains("f=801"))
        fixture.app.reply(to: 0, with: response())
        await settle()
        fixture.app.requests.removeAll()
        fixture.openRiver()
        await settle()
        XCTAssertEqual(fixture.hashes.count, 12)
        XCTAssertTrue(fixture.app.requests.isEmpty)
        fixture.controller.fetchRiverPage(2, withCallback: nil)
        XCTAssertTrue(fixture.app.requests.isEmpty)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        XCTAssertEqual(fixture.app.requests.first?.url, firstURL)
    }

    func test_cancelledFirstPageRetriesPageOneWithoutLosingAnchorOrLocalEditsThenAllowsPageTwo() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        let load = try XCTUnwrap(fixture.controller.value(forKey: "firstPageLoad") as? StoryFirstPageLoad)
        let anchor = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 4))
        fixture.table.contentOffset.y = fixture.table.rectForRow(at: anchor).minY + 17
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.fail(to: fixture.app.requests.count - 1, code: NSURLErrorCancelled)
        let story = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        fixture.stories.markStoryRead(story, feed: nil)
        fixture.controller.fetchNextPage(nil)
        await settle()
        XCTAssertTrue(fixture.app.requests.last?.url.contains("page=1&") == true)
        XCTAssertTrue(fixture.controller.value(forKey: "firstPageLoad") as? StoryFirstPageLoad === load)
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response())
        await settle()
        XCTAssertEqual((fixture.stories.activeFeedStories as? [[String: Any]])?.first?["read_status"] as? Int, 1)
        XCTAssertEqual(fixture.table.contentOffset.y - fixture.table.rectForRow(at: anchor).minY, 17, accuracy: 0.5)
        fixture.controller.fetchNextPage(nil)
        XCTAssertTrue(fixture.app.requests.last?.url.contains("page=2&") == true)
    }

    func test_failedQueuedPostsPreservePreOpeningReadSaveAndTagsWhileLaterSuccessAllowsServerChanges() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        let story = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        fixture.stories.markStoryRead(story, feed: nil)
        var edited = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        edited["user_tags"] = ["pending tag"]
        _ = fixture.stories.markStory(edited, asSaved: true, forceUpdate: true)
        fixture.open()
        await settle()
        fixture.app.beginQueuedReadPOST(hashes: ["1": ["first-page-0"]])
        fixture.app.finishPOST(success: false)
        await settle()
        fixture.app.beginQueuedSavedPOST(params: ["story_id": "first-page-0", "feed_id": 1, "user_tags": ["pending tag"]])
        fixture.app.finishPOST(success: false)
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response())
        await settle()
        let preserved = try XCTUnwrap((fixture.stories.activeFeedStories as? [[String: Any]])?.first)
        XCTAssertEqual(preserved["read_status"] as? Int, 1)
        XCTAssertEqual(preserved["starred"] as? Bool, true)
        XCTAssertEqual(preserved["user_tags"] as? [String], ["pending tag"])

        fixture.open()
        await settle()
        fixture.app.beginQueuedReadPOST(hashes: ["1": ["first-page-0"]])
        fixture.app.finishPOST(success: true)
        await settle()
        fixture.app.beginQueuedSavedPOST(params: ["story_id": "first-page-0", "feed_id": 1, "user_tags": ["pending tag"]])
        fixture.app.finishPOST(success: true)
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response())
        await settle()
        let authoritative = try XCTUnwrap((fixture.stories.activeFeedStories as? [[String: Any]])?.first)
        XCTAssertEqual(authoritative["read_status"] as? Int, 0)
        XCTAssertEqual(authoritative["starred"] as? Bool, false)
        XCTAssertEqual(authoritative["user_tags"] as? [String], [])
    }

    func test_failedQueuedPostsReassertLatestReversalsRatherThanTheirObsoleteRequestValues() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        var edited = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        fixture.stories.markStoryRead(edited, feed: nil)
        edited["user_tags"] = ["old pending tag"]
        _ = fixture.stories.markStory(edited, asSaved: true, forceUpdate: true)
        fixture.open()
        await settle()
        fixture.app.beginQueuedReadPOST(hashes: ["1": ["first-page-0"]])
        let cached = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        fixture.stories.markStoryUnread(cached, feed: nil)
        fixture.app.finishPOST(success: false)
        await settle()
        fixture.app.beginQueuedSavedPOST(params: ["story_id": "first-page-0", "feed_id": 1, "user_tags": ["old pending tag"]])
        var unsaved = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        unsaved["user_tags"] = [] as [String]
        _ = fixture.stories.markStory(unsaved, asSaved: false, forceUpdate: true)
        fixture.app.finishPOST(success: false)
        await settle()
        var stale = makeStories(0..<12)
        stale[0]["read_status"] = 1
        stale[0]["starred"] = true
        stale[0]["starred_date"] = "Stale date"
        stale[0]["user_tags"] = ["old pending tag"]
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: stale))
        await settle()
        let final = try XCTUnwrap((fixture.stories.activeFeedStories as? [[String: Any]])?.first)
        XCTAssertEqual(final["read_status"] as? Int, 0)
        XCTAssertEqual(final["starred"] as? Bool, false)
        XCTAssertNil(final["starred_date"])
        XCTAssertEqual(final["user_tags"] as? [String], [])
    }

    func test_retainedFarPageSwipeUsesGestureDirectionBeforeNewListClamping() async throws {
        for direction in [-1, 1] {
            let fixture = makeFixture()
            try await prime(fixture)
            fixture.open()
            await settle()
            fixture.app.activeStory = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?[8])
            let pages = FirstPageLoadingPages()
            pages.appDelegate = fixture.app
            pages.currentPage = StoryDetailViewController()
            pages.currentPage.pageIndex = 8
            let scroll = FirstPageGestureScroll(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            scroll.contentSize = CGSize(width: 390 * 15, height: 844 * 15)
            pages.scrollView = scroll
            fixture.app.testPages = pages
            fixture.app.releaseReadFlush()
            fixture.app.releaseSavedFlush()
            await settle()
            fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: makeStories(9..<10) + makeStories(1..<2) + makeStories(3..<4)))
            await settle()
            XCTAssertTrue(pages.pageChanges.isEmpty)
            scroll.testingDrag = true
            let rawPage = CGFloat(8 + direction)
            var projected = pages.isHorizontal ? CGPoint(x: 390 * rawPage, y: 0) : CGPoint(x: 0, y: 844 * rawPage)
            let expectedProjected = projected
            pages.scrollViewWillEndDragging(scroll, withVelocity: .zero, targetContentOffset: &projected)
            XCTAssertEqual(projected, expectedProjected, "The end-of-drag target must preserve direction around the retained frame before deceleration")
            XCTAssertTrue(pages.pageChanges.isEmpty)
            scroll.contentOffset = expectedProjected
            pages.scrollViewDidScroll(scroll)
            XCTAssertEqual(pages.pageChanges, [direction > 0 ? 0 : 2])
        }
    }

    func test_retainedArticleSurvivesReorientationAndRefreshWithoutLosingReadingOffset() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        fixture.app.activeStory = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?[8])
        let pages = FirstPageLoadingPages()
        pages.appDelegate = fixture.app
        let current = FirstPageLoadingStoryPage()
        current.appDelegate = fixture.app
        current.pageIndex = 8
        current.webView = FirstPageArticleWebView(frame: current.view.bounds)
        current.webView.scrollView.addObserver(current, forKeyPath: "contentOffset", options: [], context: nil)
        current.view.addSubview(current.webView)
        current.webView.scrollView.contentOffset.y = 321
        pages.currentPage = current
        pages.scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        pages.scrollView.contentSize = CGSize(width: 390 * 15, height: 844 * 15)
        pages.scrollView.addSubview(current.view)
        fixture.app.testPages = pages
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: makeStories(1..<4)))
        await settle()
        XCTAssertEqual(current.webView.scrollView.contentOffset.y, 321, accuracy: 0.5,
                       "StoryFirstPageLoadingTests.swift must retain its seeded document offset before testing reorientation")
        pages.scrollView.bounds.size = CGSize(width: 844, height: 390)
        pages.reorientPages()
        XCTAssertFalse(current.view.isHidden)
        XCTAssertEqual(current.pageIndex, 8)
        XCTAssertEqual(current.webView.scrollView.contentOffset.y, 321, accuracy: 0.5)
        pages.refreshPages()
        XCTAssertTrue(pages.currentPage === current)
        XCTAssertEqual(current.pageIndex, 8)
        XCTAssertFalse(current.view.isHidden)
        XCTAssertEqual(current.webView.scrollView.contentOffset.y, 321, accuracy: 0.5)
        XCTAssertTrue(pages.pageChanges.isEmpty)
        XCTAssertEqual(fixture.app.activeStory["story_hash"] as? String, "first-page-8")
        pages.changeToPreviousPage(nil)
        XCTAssertEqual(pages.pageChanges, [2])
    }

    func test_ignoredPageOneRequestDoesNotInstallAPermanentPaginationGate() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        let load = try XCTUnwrap(fixture.controller.value(forKey: "firstPageLoad") as? StoryFirstPageLoad)
        fixture.controller.pageFinished = true
        fixture.controller.fetchFeedDetail(1, withCallback: nil)
        XCTAssertTrue(fixture.controller.value(forKey: "firstPageLoad") as? StoryFirstPageLoad === load)
        XCTAssertFalse(load.pending)
        fixture.controller.pageFinished = false
        fixture.controller.fetchNextPage(nil)
        XCTAssertTrue(fixture.app.requests.last?.url.contains("page=2&") == true)
    }

    func test_successiveSearchEditsClearNormalCacheGatesAndRejectEarlierResultsInFeedsAndRivers() async throws {
        for river in [false, true] {
            let fixture = makeFixture()
            if river {
                fixture.app.riverFeeds = [1]
                fixture.openRiver()
                fixture.app.releaseReadFlush()
                fixture.app.releaseSavedFlush()
                await settle()
                fixture.app.reply(to: 0, with: response())
                await settle()
            } else {
                try await prime(fixture)
            }
            let search = UITextField()
            fixture.controller.searchField = search
            let delegate = fixture.controller as UITextFieldDelegate
            let reloadSelector = NSSelectorFromString("reloadStories")
            defer { NSObject.cancelPreviousPerformRequests(withTarget: fixture.controller, selector: reloadSelector, object: nil) }
            func edit(_ query: String) {
                search.text = query
                fixture.controller.perform(NSSelectorFromString("searchFieldDidChange:"), with: search)
            }
            func query(in index: Int) -> String? {
                guard fixture.app.requests.indices.contains(index) else { return nil }
                return URLComponents(string: fixture.app.requests[index].url)?.queryItems?.first { $0.name == "query" }?.value
            }

            edit("breeding ground for malicious")
            await settleSearchDebounce()
            let firstSearch = fixture.app.requests.count - 1
            XCTAssertEqual(query(in: firstSearch), "breeding ground for malicious")
            XCTAssertNil(fixture.controller.value(forKey: "firstPageLoad"))
            fixture.app.reply(to: firstSearch, with: response(stories: makeStories(100..<102)))
            await settle()
            XCTAssertEqual(fixture.hashes, ["first-page-100", "first-page-101"])

            XCTAssertTrue(delegate.textFieldShouldClear?(search) == true)
            search.text = ""
            let clearedRequest = fixture.app.requests.count - 1
            XCTAssertNil(query(in: clearedRequest))
            edit("Container for Chaos")
            _ = delegate.textFieldShouldReturn?(search)
            // StoryFirstPageLoadingTests.swift holds the clear-triggered normal response until the query already changed, then lets the real one-second search debounce run.
            fixture.app.reply(to: clearedRequest, with: response(stories: makeStories(200..<202)))
            await settleSearchDebounce()
            let replacement = fixture.app.requests.count - 1
            XCTAssertGreaterThan(replacement, clearedRequest)
            XCTAssertEqual(query(in: replacement), "Container for Chaos")
            XCTAssertNil(fixture.controller.value(forKey: "firstPageLoad"))
            fixture.app.reply(to: replacement, with: response(stories: makeStories(300..<302)))
            await settle()
            XCTAssertEqual(fixture.hashes, ["first-page-300", "first-page-301"])
            XCTAssertFalse(fixture.controller.pageFetching)

            while !(search.text ?? "").isEmpty { edit(String((search.text ?? "").dropLast())) }
            edit("\"container for chaos\"")
            _ = delegate.textFieldShouldReturn?(search)
            await settleSearchDebounce()
            let quoted = fixture.app.requests.count - 1
            XCTAssertGreaterThan(quoted, replacement)
            XCTAssertEqual(query(in: quoted), "\"container for chaos\"")
            fixture.app.reply(to: quoted, with: response(stories: makeStories(400..<402)))
            fixture.app.reply(to: firstSearch, with: response(stories: makeStories(100..<102)))
            fixture.app.fail(to: clearedRequest, code: NSURLErrorCancelled)
            await settle()
            XCTAssertEqual(fixture.hashes, ["first-page-400", "first-page-401"])
            XCTAssertFalse(fixture.controller.pageFetching)
            XCTAssertNil(fixture.controller.value(forKey: "firstPageLoad"))

            fixture.controller.fetchNextPage(nil)
            let nextPage = fixture.app.requests.count - 1
            XCTAssertGreaterThan(nextPage, quoted)
            XCTAssertEqual(query(in: nextPage), "\"container for chaos\"")
            XCTAssertTrue(fixture.app.requests.last?.url.contains("page=2&") == true)
        }
    }

    private func query(_ name: String, in url: String) -> String? {
        URLComponents(string: url)?.queryItems?.first { $0.name == name }?.value
    }

    private func feedPageRequest(_ page: Int, in fixture: FirstPageFixture) throws -> Int {
        try XCTUnwrap(fixture.app.requests.firstIndex {
            URLComponents(string: $0.url)?.path == "/reader/feed/1/" && query("page", in: $0.url) == String(page)
        }, "Missing real individual-feed page \(page) request")
    }

    private func exactNotificationRequest(_ hash: String, in fixture: FirstPageFixture) throws -> Int {
        let index = try XCTUnwrap(fixture.app.requests.firstIndex { query("h", in: $0.url) == hash },
                                 "An older notification needs one exact-hash lookup instead of relying on reaching its page")
        let request = fixture.app.requests[index]
        XCTAssertEqual(URLComponents(string: request.url)?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")),
                       "reader/river_stories")
        XCTAssertEqual(query("page", in: request.url), "0")
        XCTAssertEqual(query("include_hidden", in: request.url), "true")
        return index
    }

    private func settleSearchDebounce() async {
        let reloaded = expectation(description: "Real search debounce submits the latest edit")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) { reloaded.fulfill() }
        await fulfillment(of: [reloaded], timeout: 2)
    }

    private func prime(_ fixture: FirstPageFixture, stories: [[String: Any]]? = nil) async throws {
        fixture.open()
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 1)
        fixture.app.reply(to: 0, with: response(stories: stories))
        await settle()
    }

    private func settle() async {
        // StoryFirstPageLoadingTests.swift leaves queued POST callbacks withheld. After the rendering turn,
        // wait for the actual utility-queue cache work and its main publication, with the same cold-CI budget as WebKit readiness.
        let drained = expectation(description: "main queue and cache callbacks")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            StoryFirstPageCache.shared.queue.async {
                DispatchQueue.main.async { drained.fulfill() }
            }
        }
        await fulfillment(of: [drained], timeout: 30)
    }

    private func startEmptyTryFeed(_ fixture: FirstPageFixture) async {
        fixture.app.isTryFeedView = true
        fixture.app.tryFeedFeedId = "1"
        fixture.open()
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        var empty = response(stories: [])
        empty["not_yet_fetched"] = true
        empty["fetched_once"] = false
        fixture.app.reply(to: 0, with: empty)
        await settle()
    }

    private func makeFixture() -> FirstPageFixture {
        let app = FirstPageLoadingAppDelegate()
        app.activeUsername = "first-page-test-" + UUID().uuidString
        app.testURL = "https://example.test"
        app.interceptRequests()
        app.isPremium = true
        app.isPremiumArchive = true
        app.selectedIntelligence = 0
        app.recentlyReadStories = NSMutableDictionary()
        app.unreadStoryHashes = NSMutableDictionary()
        app.unsavedStoryHashes = NSMutableDictionary()
        app.dictFeeds = ["1": ["id": 1, "feed_title": "First feed", "active": 1]]
        app.dictActiveFeeds = NSMutableDictionary()
        app.dictFolders = [:]
        app.dictFoldersArray = NSMutableArray()
        let stories = FirstPageLoadingStories()
        stories.appDelegate = app
        stories.feedPage = 1
        stories.activeFeed = app.dictFeeds["1"] as? [AnyHashable: Any]
        app.storiesCollection = stories
        return makeReader(app: app, stories: stories)
    }

    private func makeReader(app: FirstPageLoadingAppDelegate, stories: FirstPageLoadingStories) -> FirstPageFixture {
        let controller = FirstPageLoadingController()
        controller.appDelegate = app
        controller.storiesCollection = stories
        controller.dashboardIndex = -1
        app.testController = controller
        let table = FirstPageLoadingTable(frame: CGRect(x: 0, y: 0, width: 390, height: 320), style: .plain)
        table.estimatedRowHeight = 0
        controller.storyTitlesTable = table
        controller.view = UIView(frame: table.frame)
        controller.view.addSubview(table)
        controller.messageView = UIView()
        controller.messageLabel = UILabel()
        controller.messageView.isHidden = true
        controller.setValue(NSCache<NSString, NSString>(), forKey: "storyPreviewTextCache")
        controller.setValue(NSCache<NSString, NSNumber>(), forKey: "storyHeightCache")
        table.dataSource = controller
        table.delegate = controller
        return FirstPageFixture(app: app, stories: stories, controller: controller, table: table)
    }

    private func response(stories: [[String: Any]]? = nil) -> [String: Any] {
        ["feed_id": 1, "stories": stories ?? makeStories(0..<12), "classifiers": [:],
         "feed_authors": [], "feed_tags": [], "user_profiles": []]
    }

    private func makeStories(_ indices: Range<Int>) -> [[String: Any]] {
        indices.map { ["story_hash": "first-page-\($0)", "story_feed_id": 1,
                       "story_title": "Story \($0)", "story_content": "<p>Body \($0)</p>",
                       "story_timestamp": 1_800_000_000 - $0, "read_status": 0,
                       "starred": false, "user_tags": [], "image_urls": [],
                       "intelligence": ["feed": 0, "author": 0, "tags": 0, "title": 0]] }
    }
}

@MainActor private final class FirstPageNotificationPresentation {
    let fixture: FirstPageFixture
    let filterKey: String
    let previousFilter: Any?
    let previousKeyWindow: UIWindow?
    let window: UIWindow

    init(fixture: FirstPageFixture) throws {
        self.fixture = fixture
        fixture.stories.useProductionReadFilter = true
        filterKey = try XCTUnwrap(fixture.stories.readFilterKey)
        previousFilter = UserDefaults.standard.object(forKey: filterKey)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        fixture.app.window = window
        UserDefaults.standard.set("unread", forKey: filterKey)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 660)
        let root = UIViewController()
        root.view.backgroundColor = .systemBackground
        window.rootViewController = root
        fixture.controller.view.frame = CGRect(x: 0, y: 52, width: 390, height: 608)
        fixture.table.frame = fixture.controller.view.bounds
        root.view.addSubview(fixture.controller.view)
        let header = UILabel(frame: CGRect(x: 16, y: 8, width: 358, height: 36))
        header.text = "First feed"
        header.font = .preferredFont(forTextStyle: .headline)
        root.view.addSubview(header)
        window.makeKeyAndVisible()
        fixture.app.storyPresented = {}
    }

    func close() {
        let selectedHash = fixture.app.activeStory?["story_hash"] as? String
        fixture.app.inFindingStoryMode = false
        fixture.controller.resetFeedDetail()
        for request in fixture.app.requests { request.task?.cancel() }
        fixture.app.requests.removeAll()
        fixture.app.readFlushes.removeAll()
        fixture.app.savedFlushes.removeAll()
        fixture.app.storyPresented = nil
        fixture.app.testPages = nil
        if let selectedHash, ReadTimeTracker.shared.currentStoryHash == selectedHash {
            ReadTimeTracker.shared.stopTracking()
            _ = ReadTimeTracker.shared.getAndResetReadTime(storyHash: selectedHash)
        }
        window.isHidden = true
        fixture.app.window = nil
        previousKeyWindow?.makeKey()
        if let previousFilter { UserDefaults.standard.set(previousFilter, forKey: filterKey) }
        else { UserDefaults.standard.removeObject(forKey: filterKey) }
    }
}

@MainActor private struct FirstPageFixture {
    let app: FirstPageLoadingAppDelegate
    let stories: FirstPageLoadingStories
    let controller: FirstPageLoadingController
    let table: UITableView
    var hashes: [String] { (stories.activeFeedStories as? [[String: Any]] ?? []).compactMap { $0["story_hash"] as? String } }

    func openRiver() {
        let selector = NSSelectorFromString("loadRiverFeedDetailView:withFolder:")
        typealias Load = @convention(c) (AnyObject, Selector, AnyObject, NSString) -> Void
        let implementation = unsafeBitCast(app.method(for: selector), to: Load.self)
        implementation(app, selector, controller, "everything")
    }

    func open() {
        let selector = NSSelectorFromString("loadFeedDetailView:")
        typealias Load = @convention(c) (AnyObject, Selector, Bool) -> Void
        let implementation = unsafeBitCast(app.method(for: selector), to: Load.self)
        implementation(app, selector, false)
    }
}

private final class FirstPageLoadingStories: StoriesCollection {
    var readFilter = "all"
    var order = "newest"
    var useProductionReadFilter = false
    override var activeReadFilter: String! { useProductionReadFilter ? super.activeReadFilter : readFilter }
    override var activeOrder: String! { order }
}

@MainActor private final class FirstPageSelectionFeeds: FeedsViewController {
    override func viewDidLoad() {}
    @objc(highlightSelection) func suppressSelectionChrome() {}
    override func clearDashboard() {}
}

@MainActor private final class FirstPageLoadingController: FeedDetailViewController {
    var usesProductionDeferredReload = false
    var fetchingTitle: String?
    var testRefreshPollInterval: TimeInterval = 2
    var testRefreshTimeout: TimeInterval = 60
    override var tryFeedRefreshPollInterval: TimeInterval { testRefreshPollInterval }
    override var tryFeedRefreshTimeout: TimeInterval { testRefreshTimeout }
    var testRowHeight: CGFloat = 80
    var markedHashes: [String] = []
    var markReadAttempts: [String] = []
    var holdCache = false
    var heldCache: [() -> Void] = []
    var cacheLookupFinished: (() -> Void)?
    var scrollAnimationFinished: (() -> Void)?
    @objc(scrollViewDidEndScrollingAnimation:)
    func didFinishTitleReveal(_ scrollView: UIScrollView) { scrollAnimationFinished?() }
    func releaseCache() { if !heldCache.isEmpty { heldCache.removeFirst()() } }
    @objc(lookupFirstPageRequest:completion:)
    func lookupSnapshot(_ request: StoryFirstPageRequest, completion: @escaping (StoryFirstPageSnapshot?) -> Void) {
        let finished = cacheLookupFinished
        StoryFirstPageCache.shared.lookup(request) { snapshot in
            let apply = {
                completion(snapshot)
                finished?()
            }
            if self.holdCache { self.heldCache.append(apply) }
            else { apply() }
        }
    }
    override var isLegacyTable: Bool { true }
    override var isMarkReadOnScroll: Bool { true }
    override func viewDidLoad() {}
    // StoryFirstPageLoadingTests.swift supplies its own outlets and delegate; appearance must
    // not replace them with UIApplication's delegate or construct the absent navigation bar.
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillDisappear(_ animated: Bool) {}
    override func viewDidDisappear(_ animated: Bool) {}
    override func reload() {
        if usesProductionDeferredReload { super.reload() }
        else { reloadTable() }
    }
    override func loadingFeed() {}
    override func updateStoryTitlesHeaderPillState() {}
    override func loadFaviconsFromActiveFeed() {}
    override func showFetchingBanner(_ title: String!, isOffline: Bool) { fetchingTitle = title }
    override func hideFetchingBanner() { fetchingTitle = nil }
    override func markStoryReadIfNeeded(_ story: [AnyHashable: Any]!, isScrolling: Bool) -> Bool {
        if let hash = story["story_hash"] as? String { markReadAttempts.append(hash) }
        if isScrolling, let hash = story["story_hash"] as? String { markedHashes.append(hash) }
        return false
    }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { testRowHeight }
    @objc(beginOfflineTimer) func suppressUnownedSQLiteFallback() {}
    @objc(cacheImagesForStories:) func suppressImageDownloads(_ stories: Any?) {}
    @objc(warmStoryPreviewCacheAroundLocation:) func suppressWarmup(_ location: Int) {}
    @objc(updateBottomNextFeedControlForScroll:) func suppressNavigationControls(_ scroll: UIScrollView) {}
}

@MainActor private final class FirstPageLoadingTable: UITableView {
    var rowReloads = 0
    var forcesUnavailableSections = false
    var recordsUnavailableSectionQueries = false
    var unavailableSectionQueries = 0
    var unavailableSectionQueryStacks: [[String]] = []
    override var numberOfSections: Int { forcesUnavailableSections ? 0 : super.numberOfSections }
    override func numberOfRows(inSection section: Int) -> Int {
        if recordsUnavailableSectionQueries, section >= numberOfSections {
            unavailableSectionQueries += 1
            unavailableSectionQueryStacks.append(Thread.callStackSymbols)
            return 0
        }
        return super.numberOfRows(inSection: section)
    }
    override func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        rowReloads += 1
        super.reloadRows(at: indexPaths, with: animation)
    }
}

@MainActor private final class NextTitleRevealRecorder: NSObject {
    let table: UITableView
    var offsets: [CGFloat] = []
    private var link: CADisplayLink?
    private var whenReady: (() -> Void)?
    private var whenPresented: (() -> Void)?
    private var stableFrames = 0
    init(table: UITableView) { self.table = table }
    func start(whenReady: @escaping () -> Void) {
        offsets = []
        stableFrames = 0
        self.whenReady = whenReady
        whenPresented = nil
        let link = CADisplayLink(target: self, selector: #selector(sample))
        link.add(to: .main, forMode: .common)
        self.link = link
    }
    @objc private func sample() {
        guard let presentation = table.layer.presentation(), table.window?.layer.presentation() != nil else {
            stableFrames = 0
            return
        }
        if let whenReady {
            // StoryFirstPageLoadingTests.swift begins the reveal only after the new window and table commit stable presentation frames.
            guard presentation.bounds == table.layer.bounds else { stableFrames = 0; return }
            stableFrames += 1
            guard stableFrames >= 2 else { return }
            self.whenReady = nil
            offsets = [presentation.bounds.origin.y]
            whenReady()
            return
        }
        offsets.append(presentation.bounds.origin.y)
        if abs(presentation.bounds.origin.y - table.contentOffset.y) < 0.5 {
            let completion = whenPresented
            whenPresented = nil
            completion?()
        }
    }
    func finishAfterPresentation(_ completion: @escaping () -> Void) {
        // StoryFirstPageLoadingTests.swift observes UIKit's final displayed frame after its scroll completion, which can precede that frame.
        whenPresented = completion
    }
    func stop() {
        link?.invalidate()
        link = nil
        whenReady = nil
        whenPresented = nil
    }
}

private final class FirstPageLoadingAppDelegate: NewsBlurAppDelegate {
    var storyPresented: (() -> Void)?
    override func popToRoot(completion: (() -> Void)!) { completion?() }
    override func reloadFeedsView(_ showLoader: Bool) {
        if storyPresented == nil { super.reloadFeedsView(showLoader) }
    }
    override func loadStoryDetailView(animated: Bool) {
        if let storyPresented { storyPresented() }
        else { super.loadStoryDetailView(animated: animated) }
    }
    override func loadStoryDetailView(atLocation location: Int, animated: Bool) {
        if let storyPresented { storyPresented() }
        else { super.loadStoryDetailView(atLocation: location, animated: animated) }
    }

    struct CapturedRequest {
        let url: String
        let parameters: [String: Any]?
        let task: URLSessionDataTask?
        let success: (URLSessionDataTask?, Any?) -> Void
        let failure: (URLSessionDataTask?, NSError?) -> Void
    }
    var requests: [CapturedRequest] = []
    var readFlushes: [() -> Void] = []
    var postResults: [(Bool) -> Void] = []
    var postURLs: [String] = []
    override func post(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask?, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error?) -> Void)!) {
        postURLs.append(urlString)
        postResults.append { passed in
            if passed { success(nil, [:]) }
            else { failure(nil, NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)) }
        }
    }
    func finishPOST(success: Bool) {
        guard !postResults.isEmpty else { XCTFail("Missing synthetic queued POST"); return }
        postResults.removeFirst()(success)
    }
    func beginQueuedReadPOST(hashes: NSDictionary) {
        guard !readFlushes.isEmpty else { XCTFail("Missing queued read flush"); return }
        let callback: @convention(block) () -> Void = readFlushes.removeFirst()
        let selector = NSSelectorFromString("syncQueuedReadStories:withStories:withCallback:")
        typealias Sync = @convention(c) (AnyObject, Selector, AnyObject?, NSDictionary, AnyObject) -> Void
        let implementation = unsafeBitCast(method(for: selector), to: Sync.self)
        implementation(self, selector, nil, hashes, callback as AnyObject)
    }
    func beginQueuedSavedPOST(params: NSDictionary) {
        guard !savedFlushes.isEmpty else { XCTFail("Missing queued saved flush"); return }
        let callback: @convention(block) () -> Void = savedFlushes.removeFirst()
        perform(NSSelectorFromString("syncQueuedSavedStoryParams:withCallback:"), with: params, with: callback as AnyObject)
    }
    var savedFlushes: [() -> Void] = []
    weak var testController: FeedDetailViewController?
    var testPages: StoryPagesViewController?
    var riverFeeds: [NSNumber] = []
    override func feedIdsForTopLevelRiver(withReadFilter readFilter: String!) -> [Any]! { riverFeeds }
    override func show(_ column: UISplitViewController.Column, debugInfo: String!, animated: Bool) {}
    override var storyPagesViewController: StoryPagesViewController! { testPages }
    override var feedDetailViewController: FeedDetailViewController! {
        get { testController }
        set { testController = newValue }
    }
    override func cleanUpTryFeed() {}
    override func adjustStoryDetailWebView() {}
    override func updateFeedDetailTitleView() {}

    var testURL = "https://example.test"
    override var url: String! { testURL }
    func interceptRequests() { _ = Self.installInterceptors }

    func releaseReadFlush() { if !readFlushes.isEmpty { readFlushes.removeFirst()() } }
    func releaseSavedFlush() { if !savedFlushes.isEmpty { savedFlushes.removeFirst()() } }
    func reply(to index: Int, with response: [String: Any]) {
        guard requests.indices.contains(index) else { XCTFail("Missing intercepted page request \(index)"); return }
        requests[index].task?.cancel()
        requests[index].success(nil, response)
    }

    func fail(to index: Int, code: Int = NSURLErrorNotConnectedToInternet) {
        guard requests.indices.contains(index) else { XCTFail("Missing intercepted request"); return }
        requests[index].task?.cancel()
        requests[index].failure(nil, NSError(domain: NSURLErrorDomain, code: code))
    }

    // StoryFirstPageLoadingTests.swift installs selectors only on this synthetic delegate, never on the logged-in app.
    private static let installInterceptors: Void = {
        for (original, replacement) in [
            ("GETreturningTask:parameters:success:failure:", "nb_test_GET:parameters:success:failure:"),
            ("GET:parameters:success:failure:", "nb_test_GETWithoutTask:parameters:success:failure:"),
            ("flushQueuedReadStories:withCallback:", "nb_test_readFlush:callback:"),
            ("flushQueuedSavedStories:withCallback:", "nb_test_savedFlush:callback:")
        ] {
            let method = class_getInstanceMethod(FirstPageLoadingAppDelegate.self, NSSelectorFromString(replacement))!
            class_replaceMethod(FirstPageLoadingAppDelegate.self, NSSelectorFromString(original),
                                method_getImplementation(method), method_getTypeEncoding(method))
        }
    }()

    @objc(nb_test_GET:parameters:success:failure:)
    func captureGET(_ url: String, parameters: Any?, success: @escaping (URLSessionDataTask?, Any?) -> Void,
                    failure: @escaping (URLSessionDataTask?, NSError?) -> Void) -> URLSessionDataTask? {
        // StoryFirstPageLoadingTests.swift needs a cancellable in-flight token for exact
        // lookups. This task is never resumed; synthetic callbacks still deliver every response.
        var task: URLSessionDataTask?
        if let components = URLComponents(string: url),
           components.queryItems?.contains(where: { $0.name == "h" }) == true,
           let requestURL = components.url {
            task = URLSession.shared.dataTask(with: requestURL)
        }
        requests.append(CapturedRequest(url: url, parameters: parameters as? [String: Any], task: task, success: success, failure: failure))
        return task
    }
    @objc(nb_test_GETWithoutTask:parameters:success:failure:)
    func captureGETWithoutTask(_ url: String, parameters: Any?, success: @escaping (URLSessionDataTask?, Any?) -> Void,
                              failure: @escaping (URLSessionDataTask?, NSError?) -> Void) {
        _ = captureGET(url, parameters: parameters, success: success, failure: failure)
    }
    @objc(nb_test_readFlush:callback:)
    func holdReadFlush(_ force: Bool, callback: @escaping () -> Void) { readFlushes.append(callback) }
    @objc(nb_test_savedFlush:callback:)
    func holdSavedFlush(_ force: Bool, callback: @escaping () -> Void) { savedFlushes.append(callback) }
}

@MainActor private final class FirstPageLoadingPages: StoryPagesViewController {
    var pageChanges: [Int] = []
    var advances = 0
    var usesProductionUnreadAdvance = false
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) }
    override func viewDidLoad() {}
    override func changePage(_ pageIndex: Int, animated: Bool) { pageChanges.append(pageIndex) }
    override func resizeScrollView() {}
    override func advanceToNextUnread() {
        advances += 1
        if usesProductionUnreadAdvance { super.advanceToNextUnread() }
    }
    override func resetPages() {}
    override func hidePages() {}
}

@MainActor private final class FirstPageLoadingStoryPage: StoryDetailViewController {
    var storyDrawn: (() -> Void)?
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {}
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) }
    override func viewDidLoad() {}
    override func drawStory() {
        if let storyDrawn { storyDrawn() }
        else { super.drawStory() }
    }
}

@MainActor private final class FirstPageGestureScroll: UIScrollView {
    var testingDrag = false
    override var isDragging: Bool { testingDrag }
}

// StoryFirstPageLoadingTests.swift gives a retained article a fixed 4,000pt document instead of waiting on WebKit layout.
// These tests are about pagination keeping the article and its reading offset; an off-window WKWebView's layout
// depends on WebKit process scheduling and has taken longer than 30s on CI.
@MainActor private final class FirstPageArticleWebView: WKWebView {
    private let documentScroll = UIScrollView()
    override var scrollView: UIScrollView { documentScroll }

    init(frame: CGRect) {
        super.init(frame: frame, configuration: WKWebViewConfiguration())
        documentScroll.frame = bounds
        documentScroll.contentSize = CGSize(width: frame.width, height: 4_000)
    }

    required init?(coder: NSCoder) { fatalError("StoryFirstPageLoadingTests.swift creates article web views programmatically") }
}
