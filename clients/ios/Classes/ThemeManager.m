//
//  ThemeManager.m
//  NewsBlur
//
//  Created by David Sinclair on 2015-12-06.
//  Copyright © 2015 NewsBlur. All rights reserved.
//

#import "ThemeManager.h"
#import "NewsBlurAppDelegate.h"
#import "ActivitiesViewController.h"
#import "OriginalStoryViewController.h"
#import "NewsBlur-Swift.h"

NSString * const ThemeStyleAuto = @"auto";
NSString * const ThemeStyleLight = @"light";
// ThemeManager.m migrates these retired variants to the native light and dark appearances.
static NSString * const LegacyThemeStyleSepia = @"sepia";
static NSString * const LegacyThemeStyleMedium = @"medium";
NSString * const ThemeStyleDark = @"dark";

@interface UINavigationController (Theme)

@end

@implementation UINavigationController (Theme)

- (UIStatusBarStyle)preferredStatusBarStyle {
    // ThemeManager.m sets the window's interface style, so the default style follows the theme.
    return UIStatusBarStyleDefault;
}

- (UIViewController *)childViewControllerForStatusBarStyle {
    return nil;
}

@end

@interface ThemeManager ()

@property (nonatomic, readonly) NewsBlurAppDelegate *appDelegate;
@property (nonatomic) BOOL isAutoDark;
@property (nonatomic, copy) NSString *lastAppliedTheme;

@end

@implementation ThemeManager

+ (instancetype)shared {
    return [self themeManager];
}

+ (instancetype)themeManager {
    static id themeManager = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
                      themeManager = [self new];
                  });
    
    return themeManager;
}

- (NSString *)theme {
    NSString *themeStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"theme_style"];

    if ([themeStyle isEqualToString:ThemeStyleLight] || [themeStyle isEqualToString:LegacyThemeStyleSepia]) {
        return ThemeStyleLight;
    } else if ([themeStyle isEqualToString:ThemeStyleDark] || [themeStyle isEqualToString:LegacyThemeStyleMedium]) {
        return ThemeStyleDark;
    }

    return ThemeStyleAuto;
}

- (void)setTheme:(NSString *)theme {
    [self reallySetTheme:theme];

    NSLog(@"Manually changed to theme: %@", self.themeDisplayName);  // log
}

- (void)reallySetTheme:(NSString *)theme {
    if (![self isValidTheme:theme]) {
        return;
    }

    [[NSUserDefaults standardUserDefaults] setObject:theme forKey:@"theme_style"];
    [self updateTheme];
}

- (void)migrateLegacyThemePreferences {
    // ThemeManager.m: Warm and Gray were retired for native styling; keep each user on the nearest appearance.
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSString *themeStyle = [prefs objectForKey:@"theme_style"];

    if ([themeStyle isEqualToString:LegacyThemeStyleSepia]) {
        [prefs setObject:ThemeStyleLight forKey:@"theme_style"];
    } else if ([themeStyle isEqualToString:LegacyThemeStyleMedium]) {
        [prefs setObject:ThemeStyleDark forKey:@"theme_style"];
    }

    if ([prefs boolForKey:@"theme_follow_system"]) {
        [prefs setObject:ThemeStyleAuto forKey:@"theme_style"];
    }

    for (NSString *key in @[@"theme_light", @"theme_dark", @"theme_follow_system", @"theme_auto_toggle", @"theme_auto_brightness", @"theme_gesture"]) {
        [prefs removeObjectForKey:key];
    }
}

- (NSString *)themeDisplayName {
    NSString *theme = self.theme;

    if ([theme isEqualToString:ThemeStyleDark]) {
        return @"Dark";
    } else if ([theme isEqualToString:ThemeStyleLight]) {
        return @"Light";
    } else {
        return @"Auto";
    }
}

- (NSString *)themeCSSSuffix {
    return self.isDarkTheme ? @"Dark" : @"Light";
}

- (BOOL)isAutoTheme {
    return [self.theme isEqualToString:ThemeStyleAuto];
}

- (BOOL)isDarkTheme {
    NSString *theme = self.theme;

    if ([theme isEqualToString:ThemeStyleAuto]) {
        return self.isSystemDark;
    }

    return [theme isEqualToString:ThemeStyleDark];
}

- (BOOL)isSystemDark {
    return self.appDelegate.window.windowScene.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
}

- (BOOL)isLikeSystem {
    return self.isDarkTheme == self.isSystemDark;
}

- (NSString *)effectiveTheme {
    return self.isDarkTheme ? ThemeStyleDark : ThemeStyleLight;
}

- (BOOL)isValidTheme:(NSString *)theme {
    return [theme isEqualToString:ThemeStyleAuto] || [theme isEqualToString:ThemeStyleLight] || [theme isEqualToString:ThemeStyleDark];
}

- (NewsBlurAppDelegate *)appDelegate {
    return (NewsBlurAppDelegate *)[UIApplication sharedApplication].delegate;
}

- (UIColor *)fixedColorFromRGB:(NSInteger)rgbValue {
    CGFloat red = ((rgbValue & 0xFF0000) >> 16) / 255.0;
    CGFloat green = ((rgbValue & 0xFF00) >> 8) / 255.0;
    CGFloat blue = ((rgbValue & 0xFF)) / 255.0;
    
    return [UIColor colorWithRed:red green:green blue:blue alpha:1.0];
}

- (UIColor *)storyListBackgroundColor {
    // ThemeManager.m keeps loading, uncovered row backs and settled story artwork on one surface.
    return [self resolvedColor:UIColor.systemBackgroundColor];
}

- (UITraitCollection *)themeTraitCollection {
    return [UITraitCollection traitCollectionWithUserInterfaceStyle:self.isDarkTheme ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight];
}

// ThemeManager.m resolves every color for the active theme, as the original palette did. Callers
// take .CGColor for layers and gradients, and updateTheme repaints them when the theme changes.
- (UIColor *)resolvedColor:(UIColor *)color {
    return [color resolvedColorWithTraitCollection:self.themeTraitCollection];
}

+ (CGFloat)luminanceOfRGB:(NSInteger)rgbValue {
    CGFloat red = ((rgbValue & 0xFF0000) >> 16) / 255.0;
    CGFloat green = ((rgbValue & 0xFF00) >> 8) / 255.0;
    CGFloat blue = ((rgbValue & 0xFF)) / 255.0;

    return 0.299 * red + 0.587 * green + 0.114 * blue;
}

// ThemeManager.m maps the roles in NewsBlur's original palette (see clients/ios/CLAUDE.md) to
// semantic system colors. A pair only maps when its dark value plays the same role, so a fixed
// white or black that stays the same in both appearances keeps its literal value.
+ (UIColor *)systemColorForLightRGB:(NSInteger)lightRGBValue darkRGB:(NSInteger)darkRGBValue {
    BOOL darkIsDark = [self luminanceOfRGB:darkRGBValue] < 0.35;
    BOOL darkIsLight = [self luminanceOfRGB:darkRGBValue] > 0.45;

    switch (lightRGBValue) {
        case 0xFFFFFF:
            return darkIsDark ? UIColor.systemBackgroundColor : nil;
        case 0xd7dadf:
        case 0xe0e0e0:
        case 0xE3E6E0:
            return darkIsDark ? UIColor.systemGroupedBackgroundColor : nil;
        case 0xf4f4f4:
        case 0xECEEEA:
            return darkIsDark ? UIColor.secondarySystemBackgroundColor : nil;
        case 0xE9E8E4:
            return darkIsDark ? UIColor.separatorColor : nil;
        case 0x000000:
        case 0x333333:
            return darkIsLight ? UIColor.labelColor : nil;
        case 0x8F918B:
        case 0x999999:
            return UIColor.secondaryLabelColor;
        case NEWSBLUR_LINK_COLOR:
            return UIColor.linkColor;
        default:
            return nil;
    }
}

- (UIColor *)colorFromLightRGB:(NSInteger)lightRGBValue darkRGB:(NSUInteger)darkRGBValue {
    UIColor *systemColor = [ThemeManager systemColorForLightRGB:lightRGBValue darkRGB:darkRGBValue];

    if (systemColor) {
        return [self resolvedColor:systemColor];
    }

    return [self fixedColorFromRGB:self.isDarkTheme ? darkRGBValue : lightRGBValue];
}

- (UIColor *)colorFromLightRGB:(NSInteger)lightRGBValue sepiaRGB:(NSUInteger)sepiaRGBValue mediumRGB:(NSUInteger)mediumRGBValue darkRGB:(NSUInteger)darkRGBValue {
    // ThemeManager.m: the Warm and Gray values are retired; callers keep their argument lists.
    return [self colorFromLightRGB:lightRGBValue darkRGB:darkRGBValue];
}

- (UIColor *)themedColorFromRGB:(NSInteger)rgbValue {
    // Debug method to log all of the unique colors; leave commented out
//        [self debugColor:rgbValue];

    NSInteger invertedRGBValue = 0xFFFFFF - (rgbValue & 0xFFFFFF);

    return [self colorFromLightRGB:rgbValue darkRGB:invertedRGBValue];
}

+ (UIColor *)colorFromRGB:(NSArray<NSNumber *> *)rgbValues {
    if (rgbValues.count == 1) {
        return [ThemeManager.shared themedColorFromRGB:rgbValues[0].integerValue];
    } else if (rgbValues.count == 2) {
        return [ThemeManager.shared colorFromLightRGB:rgbValues[0].integerValue darkRGB:rgbValues[1].integerValue];
    } else if (rgbValues.count == 4) {
        return [ThemeManager.shared colorFromLightRGB:rgbValues[0].integerValue darkRGB:rgbValues[3].integerValue];
    } else {
        @throw [NSException exceptionWithName:@"Invalid parameter to Theme Manager" reason:@"Should be an array of 1, 2, or 4 RGB colors." userInfo:nil];
    }
}

- (UIImage *)themedImage:(UIImage *)image {
    if (self.isDarkTheme) {
        CIImage *coreImage = [CIImage imageWithCGImage:image.CGImage];
        CIFilter *filter = [CIFilter filterWithName:@"CIColorInvert"];
        [filter setValue:coreImage forKey:kCIInputImageKey];
        CIImage *result = [filter valueForKey:kCIOutputImageKey];

        return [UIImage imageWithCIImage:result scale:image.scale orientation:image.imageOrientation];
    } else {
        return image;
    }
}

- (void)updateNavigationController:(UINavigationController *)navigationController {
    navigationController.navigationBar.tintColor = nil;
    navigationController.navigationBar.barTintColor = ThemeManager.barBackgroundColor;
    navigationController.navigationBar.backgroundColor = ThemeManager.barBackgroundColor;
}

- (void)updateBackgroundOfView:(UIView *)view {
    view.backgroundColor = [self resolvedColor:UIColor.systemGroupedBackgroundColor];
}

- (void)updateSegmentedControl:(UISegmentedControl *)segmentedControl {
    // ThemeManager.m restores the stock segmented control look.
    segmentedControl.tintColor = nil;
    segmentedControl.backgroundColor = nil;
    segmentedControl.selectedSegmentTintColor = nil;
    [segmentedControl setTitleTextAttributes:nil forState:UIControlStateNormal];
    [segmentedControl setTitleTextAttributes:nil forState:UIControlStateSelected];
    segmentedControl.layer.borderWidth = 0;
}

- (void)updateThemeSegmentedControl:(UISegmentedControl *)segmentedControl {
    [self updateSegmentedControl:segmentedControl];
    
    segmentedControl.tintColor = [UIColor clearColor];
#if !TARGET_OS_MACCATALYST
    segmentedControl.backgroundColor = [UIColor clearColor];
#endif
    segmentedControl.selectedSegmentTintColor = [UIColor clearColor];
}

- (void)debugColor:(NSInteger)rgbValue {
    static NSMutableSet *colors = nil;
    
    if (!colors) {
        colors = [NSMutableSet set];
    }
    
    [colors addObject:[NSString stringWithFormat:@"0x%06lX", (long)rgbValue]];
    
    NSLog(@"all unique colors: %@", [[colors allObjects] sortedArrayUsingSelector:@selector(compare:)]);  // log
}

- (void)prepareForWindow:(UIWindow *)window {
    [self migrateLegacyThemePreferences];
    [self setupTheme];
}

+ (UIColor *)barBackgroundColor {
    // ThemeManager.m: opaque bars use the native opaque-bar color. Screens that pin a header over
    // content (the Duo rail, story titles and reader) read it through UINavigationBar's appearance.
    return [ThemeManager.shared resolvedColor:UIColor.systemBackgroundColor];
}

- (void)setupTheme {
    // ThemeManager.m: bar tint, titles and segmented controls use the system appearance.
    [UINavigationBar appearance].barTintColor = ThemeManager.barBackgroundColor;
    [UINavigationBar appearance].backgroundColor = ThemeManager.barBackgroundColor;
    [UIToolbar appearance].barTintColor = ThemeManager.barBackgroundColor;
    self.appDelegate.window.backgroundColor = UIColor.systemBackgroundColor;
#if TARGET_OS_MACCATALYST
    // ThemeManager.m leaves the shared desktop material visible behind the sidebar and frame.
    self.appDelegate.window.backgroundColor = UIColor.clearColor;
    self.appDelegate.window.opaque = NO;
#endif

    // ThemeManager.m: Auto leaves the window unpinned so iOS drives dynamic colors and trait
    // changes; an explicit Light or Dark choice overrides the system appearance.
    if (self.isAutoTheme) {
        self.appDelegate.window.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
    } else if (self.isDarkTheme) {
        self.appDelegate.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    } else {
        self.appDelegate.window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    }

    UIViewController *topViewController = self.appDelegate.window.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    [topViewController setNeedsStatusBarAppearanceUpdate];
}

- (void)updateTheme {
    NSString *nextTheme = self.effectiveTheme;
    BOOL animateChange = self.lastAppliedTheme && ![self.lastAppliedTheme isEqualToString:nextTheme];
    self.lastAppliedTheme = nextTheme;
    UIView *themeSnapshot = animateChange ? [ReaderMotion beginThemeTransition:self.appDelegate.window] : nil;
    NewsBlurAppDelegate *appDelegate = self.appDelegate;

    self.isAutoDark = self.isSystemDark;

    [self setupTheme];

    [appDelegate.splitViewController updateTheme];
    [appDelegate.feedsViewController updateTheme];
    [appDelegate.activitiesViewController updateTheme];
    [appDelegate.feedDetailViewController updateTheme];
    [appDelegate.detailViewController updateTheme];
    [appDelegate.storyPagesViewController updateTheme];
    [appDelegate.originalStoryViewController updateTheme];

    [self updatePreferencesTheme];
    if (themeSnapshot) [ReaderMotion finishThemeTransition:themeSnapshot];
}

- (void)updatePreferencesTheme {
    // SwiftUI PreferencesView handles its own theming
}

- (void)updateForSystemAppearance {
    [self systemAppearanceDidChange:self.isSystemDark];
}

- (void)systemAppearanceDidChange:(BOOL)isDark {
    if (self.isAutoTheme && isDark != self.isAutoDark) {
        [self updateTheme];

        NSLog(@"System changed to %@ appearance", isDark ? @"dark" : @"light");  // log
    }
}

@end
