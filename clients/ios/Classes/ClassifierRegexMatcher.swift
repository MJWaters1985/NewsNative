import Foundation

/// ClassifierRegexMatcher.swift runs readers' regex classifiers against story text within a time budget. A valid pattern
/// like (a+)+$ backtracks for minutes on a long story it doesn't match, so each search asks NSRegularExpression for
/// progress callbacks and stops once its budget runs out, reporting that it couldn't tell rather than a wrong answer.
@objcMembers final class ClassifierRegexMatcher: NSObject {
    enum Outcome: Equatable {
        case matches
        case noMatch
        /// The search ran past its budget, so whether the pattern matches is unknown.
        case timedOut
    }

    /// For saved patterns checked on the main thread while a story or its header draws.
    static let drawingBudget: TimeInterval = 0.05

    static func outcome(of regex: NSRegularExpression, in text: String, budget: TimeInterval) -> Outcome {
        let deadline = ProcessInfo.processInfo.systemUptime + budget
        var outcome = Outcome.noMatch
        regex.enumerateMatches(in: text, options: [.reportProgress], range: NSRange(text.startIndex..., in: text)) { result, _, stop in
            if result != nil {
                outcome = .matches
                stop.pointee = true
            } else if ProcessInfo.processInfo.systemUptime > deadline {
                outcome = .timedOut
                stop.pointee = true
            }
        }
        return outcome
    }

    /// The pattern's outcome, or nil when it isn't a valid regex. Patterns are case insensitive, like the server's.
    static func outcome(of pattern: String, in text: String, budget: TimeInterval) -> Outcome? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        return outcome(of: regex, in: text, budget: budget)
    }

    /// Every match, for StoryDetailObjCViewController.m's story header, or nil when the budget ran out first.
    static func matches(of regex: NSRegularExpression, in text: String, budget: TimeInterval) -> [NSTextCheckingResult]? {
        let deadline = ProcessInfo.processInfo.systemUptime + budget
        var matches: [NSTextCheckingResult] = []
        var timedOut = false
        regex.enumerateMatches(in: text, options: [.reportProgress], range: NSRange(text.startIndex..., in: text)) { result, _, stop in
            if let result { matches.append(result) }
            if ProcessInfo.processInfo.systemUptime > deadline {
                timedOut = true
                stop.pointee = true
            }
        }
        return timedOut ? nil : matches
    }

    /// The first match for StoryDetailObjCViewController.m's story header, or nil when there is none in the budget.
    static func firstMatch(of regex: NSRegularExpression, in text: String, budget: TimeInterval) -> NSTextCheckingResult? {
        let deadline = ProcessInfo.processInfo.systemUptime + budget
        var match: NSTextCheckingResult?
        regex.enumerateMatches(in: text, options: [.reportProgress], range: NSRange(text.startIndex..., in: text)) { result, _, stop in
            if let result {
                match = result
                stop.pointee = true
            } else if ProcessInfo.processInfo.systemUptime > deadline {
                stop.pointee = true
            }
        }
        return match
    }
}
