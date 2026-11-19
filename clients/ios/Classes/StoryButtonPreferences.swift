import UIKit

/// StoryButtonPreferences.swift: whether the Save button under a story is shown. The choices sync with
/// the server's user_profile.preferences, so they follow the account to other NewsBlur-compatible clients.
@objcMembers final class StoryButtonPreferences: NSObject {
    /// The story buttons in reading order, with the NSUserDefaults key each uses.
    static let storyButtons: [(name: String, localKey: String)] = [
        ("save", "show_sideoption_save")
    ]

    private static var defaults: UserDefaults { .standard }

    /// Whether the story button named save is shown (StoryDetailObjCViewController.m).
    static func showsStoryButton(_ name: String) -> Bool {
        guard let key = storyButtons.first(where: { $0.name == name })?.localKey else { return false }
        return defaults.object(forKey: key) == nil || defaults.bool(forKey: key)
    }

    static func isStoryButtonKey(_ key: String) -> Bool {
        storyButtons.contains { $0.localKey == key }
    }

    /// Adopts the server's values from user_profile.preferences after /reader/feeds (FeedsObjCViewController.m).
    static func syncFromUserProfile(_ userProfile: [AnyHashable: Any]?) {
        guard let userProfile, let preferences = jsonObject(userProfile["preferences"]) else { return }
        var changed = false
        for button in storyButtons {
            guard let value = bool(preferences[button.localKey]) else { continue }
            if defaults.object(forKey: button.localKey) as? Bool != value {
                defaults.set(value, forKey: button.localKey)
                changed = true
            }
        }
        if changed {
            refreshStoryButtons()
        }
    }

    /// PreferencesView.swift stored a new value. Returns whether it was a story button preference, after sending it
    /// to the server and redrawing the loaded stories.
    static func preferenceDidChange(_ key: String?) -> Bool {
        guard let key, isStoryButtonKey(key) else { return false }
        let value = defaults.object(forKey: key) == nil || defaults.bool(forKey: key)
        send([key: value ? "true" : "false"])
        refreshStoryButtons()
        return true
    }

    /// Redraws the story buttons on the loaded story pages after a show/hide toggle changes.
    static func refreshStoryButtons() {
        guard let pages = NewsBlurAppDelegate.shared()?.storyPagesViewController else { return }
        for page in [pages.previousPage, pages.currentPage, pages.nextPage] {
            page?.refreshSideOptions()
        }
    }

    private static func send(_ values: [String: String]) {
        guard let appDelegate = NewsBlurAppDelegate.shared() else { return }
        updateCachedProfile(values)
        let base = appDelegate.url ?? ""
        appDelegate.post("\(base)/profile/set_preference", parameters: values, success: nil, failure: { _, error in
            NSLog("Failed to save story button preferences %@: %@", values.keys.joined(separator: ", "),
                  (error as NSError?) ?? NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown))
        })
    }

    /// Mirrors FeedsObjCViewController.m's updateCachedUserProfilePreferenceWithKey: so later reads see the change.
    private static func updateCachedProfile(_ values: [String: String]) {
        guard let appDelegate = NewsBlurAppDelegate.shared(),
              let profile = appDelegate.dictUserProfile, !profile.isEmpty else { return }
        var userProfile = profile
        var preferences = jsonObject(userProfile["preferences"]) ?? [:]
        for (key, value) in values {
            // apps/profile/views.py set_preference turns only "true" and "false" into booleans.
            preferences[key] = value == "true"
        }
        userProfile["preferences"] = preferences
        appDelegate.dictUserProfile = userProfile
    }

    private static func jsonObject(_ value: Any?) -> [String: Any]? {
        if let dictionary = value as? [String: Any] { return dictionary }
        if let dictionary = value as? NSDictionary {
            return Dictionary(uniqueKeysWithValues: dictionary.compactMap { key, value in
                (key as? String).map { ($0, value) }
            })
        }
        guard let string = value as? String, let data = string.data(using: .utf8) else { return nil }
        return jsonObject(try? JSONSerialization.jsonObject(with: data))
    }

    private static func bool(_ value: Any?) -> Bool? {
        switch value {
        case let number as NSNumber: return number.boolValue
        case let string as String:
            switch string.lowercased() {
            case "true", "1", "yes", "on": return true
            case "false", "0", "no", "off": return false
            default: return nil
            }
        default: return nil
        }
    }
}
