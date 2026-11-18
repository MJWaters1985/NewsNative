import XCTest

@testable import NewsBlur

/// ClassifierRegexMatcherTests.swift checks that a reader's regex can't freeze story scoring or a story header by
/// backtracking for minutes on story text it doesn't match.
@MainActor final class Test_ClassifierRegexMatcher: XCTestCase {
    /// (a+)+$ tries every way to split a run of a's before giving up, so this text would take years unbounded.
    private let catastrophicPattern = "(a+)+$"
    private let longNonMatchingText = "<p>" + String(repeating: "a", count: 20_000) + "!</p>"

    func test_catastrophicPatternStopsWithinItsBudgetInsteadOfGuessing() {
        let started = ProcessInfo.processInfo.systemUptime
        let outcome = ClassifierRegexMatcher.outcome(of: catastrophicPattern, in: longNonMatchingText,
                                                  budget: ClassifierRegexMatcher.drawingBudget)
        let elapsed = ProcessInfo.processInfo.systemUptime - started

        XCTAssertEqual(outcome, .timedOut, "Scoring treats it as unknown rather than reporting no match")
        // The search checks its deadline every fraction of a millisecond. The margin only absorbs CI runner stalls.
        XCTAssertLessThan(elapsed, ClassifierRegexMatcher.drawingBudget + SimulatorTestTiming.realWorkTimeout)
    }

    func test_ordinaryPatternsStillMatchCaseInsensitively() {
        let story = "<p>Swift 6.2 ships with stricter concurrency checking.</p>"
        let budget = ClassifierRegexMatcher.drawingBudget
        XCTAssertEqual(ClassifierRegexMatcher.outcome(of: "\\bswift\\b", in: story, budget: budget), .matches)
        XCTAssertEqual(ClassifierRegexMatcher.outcome(of: "kotlin|java", in: story, budget: budget), .noMatch)
        XCTAssertEqual(ClassifierRegexMatcher.outcome(of: catastrophicPattern, in: "aaaa", budget: budget), .matches)
        XCTAssertNil(ClassifierRegexMatcher.outcome(of: "(unclosed", in: story, budget: budget), "An invalid pattern has no outcome")
    }

    func test_storyHeaderMatchesGiveUpWithinTheirBudget() throws {
        let regex = try NSRegularExpression(pattern: catastrophicPattern, options: [.caseInsensitive])
        let title = String(repeating: "a", count: 5_000) + "!"
        let started = ProcessInfo.processInfo.systemUptime
        XCTAssertNil(ClassifierRegexMatcher.matches(of: regex, in: title, budget: ClassifierRegexMatcher.drawingBudget),
                     "StoryDetailObjCViewController.m leaves the title unmarked")
        XCTAssertNil(ClassifierRegexMatcher.firstMatch(of: regex, in: title, budget: ClassifierRegexMatcher.drawingBudget))
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - started,
                          2 * ClassifierRegexMatcher.drawingBudget + SimulatorTestTiming.realWorkTimeout)

        let words = try NSRegularExpression(pattern: "\\bswift\\b", options: [.caseInsensitive])
        let headline = "Swift on the server, Swift on the watch"
        let found = ClassifierRegexMatcher.matches(of: words, in: headline, budget: ClassifierRegexMatcher.drawingBudget)
        XCTAssertEqual(found?.map(\.range), [NSRange(location: 0, length: 5), NSRange(location: 21, length: 5)])
        XCTAssertEqual(ClassifierRegexMatcher.firstMatch(of: words, in: headline, budget: ClassifierRegexMatcher.drawingBudget)?.range,
                       NSRange(location: 0, length: 5))
    }
}
