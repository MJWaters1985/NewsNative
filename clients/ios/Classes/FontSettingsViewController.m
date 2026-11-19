//
//  FontPopover.m
//  NewsBlur
//
//  Created by Roy Yang on 6/18/12.
//  Copyright (c) 2012-2015 NewsBlur. All rights reserved.
//

#import "FontSettingsViewController.h"
#import "NewsBlurAppDelegate.h"
#import "MenuTableViewCell.h"
#import "StoriesCollection.h"
#import "FontListViewController.h"
#import "MenuViewController.h"
#import "NewsBlur-Swift.h"

@interface FontSettingsViewController ()

@property (nonatomic, strong) NSMutableArray *fonts;

@end

@implementation FontSettingsViewController

#define kMenuOptionHeight 48

- (BOOL)isGoToFeedEnabled {
    BOOL isRiver = self.appDelegate.storiesCollection.isRiverView;
    NSString *feedId = [NSString stringWithFormat:@"%@", self.appDelegate.activeStory[@"story_feed_id"]];
    return isRiver && [[self.appDelegate getFeed:feedId] isKindOfClass:NSDictionary.class];
}

// FontSettingsViewController.m groups actions independently of optional rows and phone-only controls.
- (NSArray<NSArray<NSNumber *> *> *)menuGroups {
    // FontSettingsViewController.m: action 6 goes to the story's feed and 14 opens Keyboard Shortcuts.
    NSMutableArray *tools = [NSMutableArray array];
    if ([self isGoToFeedEnabled]) [tools addObject:@6];
    [tools addObject:@14];
    NSInteger last = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone ? 13 : 12;
    NSMutableArray *appearance = [NSMutableArray array];
    for (NSInteger row = 7; row <= last; row++) [appearance addObject:@(row)];
    return @[@[@1, @0], @[@2], tools, appearance];
}

- (NSInteger)actionAtIndexPath:(NSIndexPath *)indexPath {
    return [self menuGroups][indexPath.section][indexPath.row].integerValue;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.menuGroups.count; }

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return section == 0 ? 0 : 12;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0) return nil;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 12)];
    header.backgroundColor = MenuTableViewCell.menuBackgroundColor;
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(14, 5.5, MAX(0, header.bounds.size.width - 28), 1 / MAX(1, self.traitCollection.displayScale))];
    line.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    line.backgroundColor = MenuTableViewCell.menuSeparatorColor;
    [header addSubview:line];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section { return 0; }

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    
    self.menuTableView.backgroundColor = MenuTableViewCell.menuBackgroundColor;
    self.menuTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.menuTableView.sectionHeaderTopPadding = 0;
    self.menuTableView.contentInset = UIEdgeInsetsMake(8, 0, 8, 0);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.title = [NBLocalization text:@"Story Options"];
    self.navigationItem.backBarButtonItem.title = [NBLocalization text:@"Options"];
    
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    self.fonts = [NSMutableArray array];
    
    // Leave commented out for future use:
//    [self debugOutputFontNames];
    
    // Available fonts, in alphabetic order. All are system fonts; storyDetailView.css names each style class.
    [self addBuiltInFontWithName:@"Avenir-Medium" styleClass:@"NB-avenir" displayName:nil];
    [self addBuiltInFontWithName:@"AvenirNextCondensed-Regular" styleClass:@"NB-avenirnextcondensed" displayName:@"Avenir Next Condensed"];
    [self addBuiltInFontWithName:@"Georgia" styleClass:@"NB-georgia" displayName:nil];
    [self addBuiltInFontWithName:@"Helvetica" styleClass:@"NB-helvetica" displayName:nil];
    [self addBuiltInFontWithName:@"NewYork" styleClass:@"NB-newyork" displayName:@"New York"];
    [self addBuiltInFontWithName:@"Palatino-Roman" styleClass:@"NB-palatino" displayName:nil];
    [self addBuiltInFontWithName:@"SanFrancisco" styleClass:@"NB-sanfrancisco" displayName:@"San Francisco"];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if ([userPreferences stringForKey:@"story_font_size"]){
        NSString *fontSize = [userPreferences stringForKey:@"story_font_size"];
        if ([fontSize isEqualToString:@"xs"]) {
            [self.fontSizeSegment setSelectedSegmentIndex:0];
        } else if ([fontSize isEqualToString:@"small"]) {
            [self.fontSizeSegment setSelectedSegmentIndex:1];
        } else if ([fontSize isEqualToString:@"medium"]) {
            [self.fontSizeSegment setSelectedSegmentIndex:2];
        } else if ([fontSize isEqualToString:@"large"]) {
            [self.fontSizeSegment setSelectedSegmentIndex:3];
        } else if ([fontSize isEqualToString:@"xl"]) {
            [self.fontSizeSegment setSelectedSegmentIndex:4];
        }
    }
    
    if ([userPreferences stringForKey:@"story_line_spacing"]){
        NSString *lineSpacing = [userPreferences stringForKey:@"story_line_spacing"];
        if ([lineSpacing isEqualToString:@"xs"]) {
            [self.lineSpacingSegment setSelectedSegmentIndex:0];
        } else if ([lineSpacing isEqualToString:@"small"]) {
            [self.lineSpacingSegment setSelectedSegmentIndex:1];
        } else if ([lineSpacing isEqualToString:@"medium"]) {
            [self.lineSpacingSegment setSelectedSegmentIndex:2];
        } else if ([lineSpacing isEqualToString:@"large"]) {
            [self.lineSpacingSegment setSelectedSegmentIndex:3];
        } else if ([lineSpacing isEqualToString:@"xl"]) {
            [self.lineSpacingSegment setSelectedSegmentIndex:4];
        }
    }
    
    if ([userPreferences boolForKey:@"story_full_screen"]) {
        [self.fullscreenSegment setSelectedSegmentIndex:0];
    } else {
        [self.fullscreenSegment setSelectedSegmentIndex:1];
    }
    
    if ([userPreferences boolForKey:@"story_autoscroll"]) {
        [self.autoscrollSegment setSelectedSegmentIndex:1];
    } else {
        [self.autoscrollSegment setSelectedSegmentIndex:0];
    }
    
    if ([userPreferences objectForKey:@"scroll_stories_horizontally"]){
        BOOL scrollHorizontally = [userPreferences boolForKey:@"scroll_stories_horizontally"];
        if (scrollHorizontally) {
            [self.scrollOrientationSegment setSelectedSegmentIndex:0];
        } else {
            [self.scrollOrientationSegment setSelectedSegmentIndex:1];
        }
    }
    
    self.themeSegment.selectedSegmentIndex = [@[ThemeStyleAuto, ThemeStyleLight, ThemeStyleDark] indexOfObject:[ThemeManager themeManager].theme];
    
    [self.menuTableView reloadData];
    
    // -[NewsBlurAppDelegate navigationController:willShowViewController:animated:] hides this too late, so this gets mis-measured otherwise
    self.navigationController.navigationBarHidden = YES;
    CGSize available = self.view.window.bounds.size;
    if (CGSizeEqualToSize(available, CGSizeZero)) available = UIScreen.mainScreen.bounds.size;
    self.navigationController.preferredContentSize = CGSizeMake(MIN(300, available.width - 32), MIN(self.menuTableView.contentSize.height + 16, available.height - 100));
    
    self.menuTableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAlways;
}

//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
//	return YES;
//}

// allow keyboard comands
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)debugOutputFontNames {
    NSLog(@"Debugging font names");
    for (NSString *family in [[UIFont familyNames] sortedArrayUsingSelector:@selector(compare:)]) {
        NSLog(@"%@", family);
        
        for (NSString *name in [UIFont fontNamesForFamilyName:family]) {
            NSLog(@"  %@", name);
        }
    }
}
                   
- (void)addBuiltInFontWithName:(NSString *)fontName styleClass:(NSString *)styleClass displayName:(NSString *)displayName {
    UIFont *font = [UIFont fontWithName:fontName size:16.0];
    if ([fontName isEqualToString:@"SanFrancisco"]) {
        font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
    } else if ([fontName isEqualToString:@"NewYork"]) {
        UIFontDescriptor *serif = [[UIFont systemFontOfSize:16.0].fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignSerif];
        font = serif ? [UIFont fontWithDescriptor:serif size:16.0] : nil;
    }
    
    if (font) {
        if (!displayName) {
            displayName = font.familyName;
        }
        NSAttributedString *attrb = [[NSAttributedString alloc] initWithString:displayName
                                                                    attributes:@{NSFontAttributeName : font}];
        [self.fonts addObject:@{@"name" : attrb, @"style" : styleClass}];
    }
}

- (IBAction)changeFontSize:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    if ([sender selectedSegmentIndex] == 0) {
        [self.appDelegate.storyPagesViewController changeFontSize:@"xs"];
        [userPreferences setObject:@"xs" forKey:@"story_font_size"];
    } else if ([sender selectedSegmentIndex] == 1) {
        [self.appDelegate.storyPagesViewController changeFontSize:@"small"];
        [userPreferences setObject:@"small" forKey:@"story_font_size"];
    } else if ([sender selectedSegmentIndex] == 2) {
        [self.appDelegate.storyPagesViewController changeFontSize:@"medium"];
        [userPreferences setObject:@"medium" forKey:@"story_font_size"];
    } else if ([sender selectedSegmentIndex] == 3) {
        [self.appDelegate.storyPagesViewController changeFontSize:@"large"];
        [userPreferences setObject:@"large" forKey:@"story_font_size"];
    } else if ([sender selectedSegmentIndex] == 4) {
        [self.appDelegate.storyPagesViewController changeFontSize:@"xl"];
        [userPreferences setObject:@"xl" forKey:@"story_font_size"];
    }
    [userPreferences synchronize];
}

- (IBAction)changeLineSpacing:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    if ([sender selectedSegmentIndex] == 0) {
        [self.appDelegate.storyPagesViewController changeLineSpacing:@"xs"];
        [userPreferences setObject:@"xs" forKey:@"story_line_spacing"];
    } else if ([sender selectedSegmentIndex] == 1) {
        [self.appDelegate.storyPagesViewController changeLineSpacing:@"small"];
        [userPreferences setObject:@"small" forKey:@"story_line_spacing"];
    } else if ([sender selectedSegmentIndex] == 2) {
        [self.appDelegate.storyPagesViewController changeLineSpacing:@"medium"];
        [userPreferences setObject:@"medium" forKey:@"story_line_spacing"];
    } else if ([sender selectedSegmentIndex] == 3) {
        [self.appDelegate.storyPagesViewController changeLineSpacing:@"large"];
        [userPreferences setObject:@"large" forKey:@"story_line_spacing"];
    } else if ([sender selectedSegmentIndex] == 4) {
        [self.appDelegate.storyPagesViewController changeLineSpacing:@"xl"];
        [userPreferences setObject:@"xl" forKey:@"story_line_spacing"];
    }
    [userPreferences synchronize];
}

- (IBAction)changeFullscreen:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    [userPreferences setBool:[sender selectedSegmentIndex] == 0 forKey:@"story_full_screen"];
    [userPreferences synchronize];
    [self.appDelegate.storyPagesViewController changedFullscreen];
}

- (IBAction)changeAutoscroll:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    [userPreferences setBool:[sender selectedSegmentIndex] == 1 forKey:@"story_autoscroll"];
    [userPreferences synchronize];
    [self.appDelegate.storyPagesViewController changedAutoscroll];
}

- (IBAction)changeScrollOrientation:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    [userPreferences setBool:[sender selectedSegmentIndex] == 0 forKey:@"scroll_stories_horizontally"];
    [userPreferences synchronize];
    [self.appDelegate.storyPagesViewController changedScrollOrientation];
}

- (IBAction)changeTheme:(id)sender {
    NSInteger selectedIndex = [sender selectedSegmentIndex];
    NSArray<NSString *> *themes = @[ThemeStyleAuto, ThemeStyleLight, ThemeStyleDark];

    if (selectedIndex >= 0 && selectedIndex < (NSInteger)themes.count) {
        [ThemeManager themeManager].theme = themes[selectedIndex];
    }

    self.menuTableView.backgroundColor = MenuTableViewCell.menuBackgroundColor;
    self.menuTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.menuTableView.sectionHeaderTopPadding = 0;
    self.menuTableView.contentInset = UIEdgeInsetsMake(8, 0, 8, 0);
    [self.menuTableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.menuGroups[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIndentifier = @"Cell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIndentifier];
    NSUInteger iPadOffset = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone ? 0 : 1;
    NSInteger adjustedRow = [self actionAtIndexPath:indexPath];

    if (adjustedRow == 8) {
        return [self makeFontSizeTableCell];
    } else if (adjustedRow == 9) {
        return [self makeLineSpacingTableCell];
    } else if (adjustedRow == 10 && iPadOffset == 0) {
        return [self makeFullScreenTableCell];
    } else if (adjustedRow == 11 - iPadOffset) {
        return [self makeAutoscrollTableCell];
    } else if (adjustedRow == 12 - iPadOffset) {
        return [self makeScrollOrientationTableCell];
    } else if (adjustedRow == 13 - iPadOffset) {
        return [self makeThemeTableCell];
    }

    if (cell == nil) {
        cell = [[MenuTableViewCell alloc]
                initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:CellIndentifier];
    }

    // FontSettingsViewController.m reuses font-preview cells for actions, so reset both text and font.
    cell.textLabel.attributedText = nil;
    cell.textLabel.font = MenuTableViewCell.menuFont;
    cell.textLabel.textColor = UIColorFromRGB(0x303030);
    cell.textLabel.highlightedTextColor = UIColorFromRGB(0x303030);
    cell.textLabel.shadowColor = UIColorFromRGB(0xF0F0F0);
    cell.backgroundView.backgroundColor = UIColorFromRGB(0xFFFFFF);
    cell.selectedBackgroundView.backgroundColor = UIColorFromRGB(0xECEEEA);
    cell.imageView.tintColor = UIColorFromRGB(0x303030);

    if (adjustedRow == 0) {
        bool isSaved = [[self.appDelegate.activeStory objectForKey:@"starred"] boolValue];
        if (isSaved) {
            cell.textLabel.text = [NBLocalization text:@"Unsave this story"];
        } else {
            cell.textLabel.text = [NBLocalization text:@"Save this story"];
        }
        cell.imageView.image = [Utilities templateImageNamed:@"saved-stories" sized:20];
        cell.imageView.tintColor = UIColorFromRGB(0x95968F);
    } else if (adjustedRow == 1) {
        bool isRead = [[self.appDelegate.activeStory objectForKey:@"read_status"] boolValue];
        if (isRead) {
            cell.textLabel.text = [NBLocalization text:@"Mark as unread"];
        } else {
            cell.textLabel.text = [NBLocalization text:@"Mark as read"];
        }
        cell.imageView.image = [Utilities templateImageNamed:@"indicator-unread" sized:16];
        cell.imageView.tintColor = UIColorFromRGB(0x6A6659);
    } else if (adjustedRow == 2) {
        cell.textLabel.text = [NBLocalization text:@"Send to..."];
        cell.imageView.image = [Utilities templateImageNamed:@"sendto" sized:20];
        cell.imageView.tintColor = UIColorFromRGB(0xBD9146);
    } else if (adjustedRow == 6) {
        cell.textLabel.text = [NBLocalization text:@"Go to feed"];
        cell.imageView.image = [[UIImage systemImageNamed:@"newspaper"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        cell.imageView.tintColor = UIColorFromRGB(0x95968F);
    } else if (adjustedRow == 14) {
        cell.textLabel.text = [NBLocalization text:@"Keyboard Shortcuts"];
        cell.imageView.image = [[UIImage systemImageNamed:@"keyboard"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        cell.imageView.tintColor = UIColorFromRGB(0x95968F);
    } else if (adjustedRow == 7) {
        NSString *fontStyle = [[NSUserDefaults standardUserDefaults] stringForKey:@"fontStyle"];
        if (!fontStyle) {
            fontStyle = @"NB-avenirnextcondensed";
        }
        NSUInteger idx = [self.fonts indexOfObjectPassingTest:^BOOL(NSDictionary *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj[@"style"] isEqualToString:fontStyle];
        }];
        if (idx != NSNotFound) {
            NSDictionary *font = self.fonts[idx];
            NSAttributedString *name = font[@"name"];
            cell.textLabel.text = name.string;
            UIFont *previewFont = name.length ? [name attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL] : nil;
            if (previewFont) {
                cell.textLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
                                      scaledFontForFont:previewFont];
            }
        } else {
            cell.textLabel.text = [NBLocalization text:@"Font..."];
        }
        cell.imageView.image = [[UIImage imageNamed:@"choose_font.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger action = [self actionAtIndexPath:indexPath];
    if (action == 14) {
        return MAX(kMenuOptionHeight, [MenuTableViewCell heightForTitle:[NBLocalization text:@"Keyboard Shortcuts"] width:tableView.bounds.size.width]);
    }
    if (action >= 8) return kMenuOptionHeight;
    NSDictionary<NSNumber *, NSString *> *titles = @{@0: [NBLocalization text:@"Unsave this story"], @1: [NBLocalization text:@"Mark as unread"],
                                                     @2: [NBLocalization text:@"Send to…"],
                                                     @6: [NBLocalization text:@"Go to feed"], @7: [NBLocalization text:@"Font…"]};
    NSString *title = titles[@(action)];
    if (!title) return kMenuOptionHeight;
    return MAX(kMenuOptionHeight, [MenuTableViewCell heightForTitle:title width:tableView.bounds.size.width]);
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger adjustedRow = [self actionAtIndexPath:indexPath];
    if (adjustedRow >= 8 && adjustedRow != 14) {
        return nil;
    }
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger adjustedRow = [self actionAtIndexPath:indexPath];
    if (adjustedRow == 14) {
        [self.appDelegate showKeyboardShortcuts];
        return;
    }
    if (adjustedRow != 7) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }

    if (adjustedRow == 0) {
        [self.appDelegate.storiesCollection toggleStorySaved];
        [self.appDelegate.feedDetailViewController reloadWithSizing];
        [self.appDelegate.storyPagesViewController refreshHeaders];
    } else if (adjustedRow == 1) {
        [self.appDelegate.storiesCollection toggleStoryUnread];
        [self.appDelegate.feedDetailViewController reloadWithSizing];
        [self.appDelegate.storyPagesViewController refreshHeaders];
    } else if (adjustedRow == 2) {
        [self.appDelegate.storyPagesViewController openSendToDialog:self.appDelegate.storyPagesViewController.settingsPresentationBarButton];
    } else if (adjustedRow == 6) {
        [self goToFeed];
    } else if (adjustedRow == 7) {
        [self showFontList];
    }
}

- (void)goToFeed {
    NewsBlurAppDelegate *appDelegate = self.appDelegate;
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                           [appDelegate.activeStory objectForKey:@"story_feed_id"]];
    NSDictionary *feed = [appDelegate getFeed:feedIdStr];
    NSString *targetFolder = nil;

    for (NSString *folderName in appDelegate.dictFoldersArray) {
        NSArray *feeds = [appDelegate.dictFolders objectForKey:folderName];
        for (id fId in feeds) {
            if ([[NSString stringWithFormat:@"%@", fId] isEqualToString:feedIdStr]) {
                targetFolder = folderName;
                break;
            }
        }
        if (targetFolder) break;
    }

    if (targetFolder || [feed isKindOfClass:NSDictionary.class]) {
        // Clear story state so isStoryShown returns NO,
        // preventing showColumn:Secondary from pushing storyPagesVC
        appDelegate.activeStory = nil;
        appDelegate.storyPagesViewController.currentPage.activeStoryId = nil;
        appDelegate.storyPagesViewController.currentPage.view.hidden = YES;
        // Reset river view so it loads as a single feed, not a folder
        appDelegate.storiesCollection.isRiverView = NO;

        if (targetFolder) {
            [appDelegate.feedsNavigationController popToRootViewControllerAnimated:NO];
            [appDelegate loadFolder:targetFolder feedID:feedIdStr];
        } else {
            [appDelegate loadTryFeedDetailView:feedIdStr withStory:nil
                                     withUser:feed showFindingStory:NO];
        }
    }
}

- (void)deleteSite {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = [NBLocalization text:@"Deleting..."];
    
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/delete_feed",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:[self.appDelegate.storiesCollection.activeFeed objectForKey:@"id"] forKey:@"feed_id"];
    [params setObject:[self.appDelegate extractFolderName:self.appDelegate.storiesCollection.activeFolder] forKey:@"in_folder"];
    
    [self.appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self.appDelegate reloadFeedsView:YES];
        [self.appDelegate.feedsNavigationController
         popToViewController:[self.appDelegate.feedsNavigationController.viewControllers
                              objectAtIndex:0]
         animated:YES];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        NSLog(@"Error: %@", error);
        [self.appDelegate informError:error];
    }];
}

- (void)showFontList {
    FontListViewController *controller = [[FontListViewController alloc] initWithNibName:@"FontListViewController" bundle:nil];
    
    controller.fonts = self.fonts;
    
    [self.navigationController showViewController:controller sender:self];
}

- (UITableViewCell *)makeFontSizeTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = MenuTableViewCell.menuBackgroundColor;
    
    self.fontSizeSegment.frame = CGRectMake(8, 7, cell.frame.size.width - 8*2, kMenuOptionHeight - 7*2);
    // FontSettingsViewController.m keeps the size abbreviations language-neutral, like clothing sizes.
    NSArray<NSString *> *sizeTitles = @[@"XS", @"S", @"M", @"L", @"XL"];
    for (NSUInteger index = 0; index < sizeTitles.count; index++) {
        [self.fontSizeSegment setTitle:sizeTitles[index] forSegmentAtIndex:index];
    }
#if !TARGET_OS_MACCATALYST
    self.fontSizeSegment.backgroundColor = UIColorFromRGB(0xeeeeee);
#endif
    [self.fontSizeSegment setTitleTextAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0f weight:UIFontWeightMedium]} forState:UIControlStateNormal];
    [self.fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:0];
    [self.fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:1];
    [self.fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:2];
    [self.fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:3];
    [self.fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:4];
    
    [[ThemeManager themeManager] updateSegmentedControl:self.fontSizeSegment];
    
    self.fontSizeSegment.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [cell.contentView addSubview:self.fontSizeSegment];
    
    return cell;
}

- (UITableViewCell *)makeLineSpacingTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = MenuTableViewCell.menuBackgroundColor;
    
    self.lineSpacingSegment.frame = CGRectMake(8, 7, cell.frame.size.width - 8*2, kMenuOptionHeight - 7*2);
    [self.lineSpacingSegment setImage:[UIImage imageNamed:@"line_spacing_xs"] forSegmentAtIndex:0];
    [self.lineSpacingSegment setImage:[UIImage imageNamed:@"line_spacing_s"] forSegmentAtIndex:1];
    [self.lineSpacingSegment setImage:[UIImage imageNamed:@"line_spacing_m"] forSegmentAtIndex:2];
    [self.lineSpacingSegment setImage:[UIImage imageNamed:@"line_spacing_l"] forSegmentAtIndex:3];
    [self.lineSpacingSegment setImage:[UIImage imageNamed:@"line_spacing_xl"] forSegmentAtIndex:4];
#if !TARGET_OS_MACCATALYST
    self.lineSpacingSegment.backgroundColor = UIColorFromRGB(0xeeeeee);
#endif
    
    [[ThemeManager themeManager] updateSegmentedControl:self.lineSpacingSegment];
    
    self.lineSpacingSegment.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [cell.contentView addSubview:self.lineSpacingSegment];
    
    return cell;
}

- (UITableViewCell *)makeFullScreenTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = MenuTableViewCell.menuBackgroundColor;
    
    self.fullscreenSegment.frame = CGRectMake(8, 7, cell.frame.size.width - 8*2, kMenuOptionHeight - 7*2);
    [self.fullscreenSegment setTitle:[NBLocalization text:@"Full Screen"] forSegmentAtIndex:0];
    [self.fullscreenSegment setTitle:[NBLocalization text:@"Toolbar"] forSegmentAtIndex:1];
#if !TARGET_OS_MACCATALYST
    self.fullscreenSegment.backgroundColor = UIColorFromRGB(0xeeeeee);
#endif
    [self.fullscreenSegment setTitleTextAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0f weight:UIFontWeightMedium]} forState:UIControlStateNormal];
    [self.fullscreenSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:0];
    [self.fullscreenSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:1];
    
    [[ThemeManager themeManager] updateSegmentedControl:self.fullscreenSegment];
    
    self.fullscreenSegment.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [cell.contentView addSubview:self.fullscreenSegment];
    
    return cell;
}

- (UITableViewCell *)makeAutoscrollTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = MenuTableViewCell.menuBackgroundColor;
    
    self.autoscrollSegment.frame = CGRectMake(8, 7, cell.frame.size.width - 8*2, kMenuOptionHeight - 7*2);
    [self.autoscrollSegment setTitle:[NBLocalization text:@"Manual scroll"] forSegmentAtIndex:0];
    [self.autoscrollSegment setTitle:[NBLocalization text:@"Auto scroll"] forSegmentAtIndex:1];
#if !TARGET_OS_MACCATALYST
    self.autoscrollSegment.backgroundColor = UIColorFromRGB(0xeeeeee);
#endif
    [self.autoscrollSegment setTitleTextAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0f weight:UIFontWeightMedium]} forState:UIControlStateNormal];
    [self.autoscrollSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:0];
    [self.autoscrollSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:1];
    
    [[ThemeManager themeManager] updateSegmentedControl:self.autoscrollSegment];
    
    self.autoscrollSegment.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [cell.contentView addSubview:self.autoscrollSegment];
    
    return cell;
}

- (UITableViewCell *)makeScrollOrientationTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = MenuTableViewCell.menuBackgroundColor;
    
    self.scrollOrientationSegment.frame = CGRectMake(8, 7, cell.frame.size.width - 8*2, kMenuOptionHeight - 7*2);
    UIImageSymbolConfiguration *scrollIconConfig = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
    [self.scrollOrientationSegment setImage:[[UIImage systemImageNamed:@"arrow.left.and.right" withConfiguration:scrollIconConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forSegmentAtIndex:0];
    [self.scrollOrientationSegment setImage:[[UIImage systemImageNamed:@"arrow.up.and.down" withConfiguration:scrollIconConfig] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forSegmentAtIndex:1];
#if !TARGET_OS_MACCATALYST
    self.scrollOrientationSegment.backgroundColor = UIColorFromRGB(0xeeeeee);
#endif
    [self.scrollOrientationSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:0];
    [self.scrollOrientationSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:1];
    
    [[ThemeManager themeManager] updateSegmentedControl:self.scrollOrientationSegment];
    
    self.scrollOrientationSegment.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [cell.contentView addSubview:self.scrollOrientationSegment];
    
    return cell;
}

- (UITableViewCell *)makeThemeTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = MenuTableViewCell.menuBackgroundColor;

    self.themeSegment.frame = CGRectMake(8, 7, cell.frame.size.width - 8*2, kMenuOptionHeight - 7*2);
    // FontSettingsViewController.m uses the native segmented control with SF Symbols for Auto, Light and Dark.
    [self.themeSegment removeAllSegments];
    [self.themeSegment insertSegmentWithTitle:[NBLocalization text:@"Auto"] atIndex:0 animated:NO];
    [self.themeSegment insertSegmentWithImage:[UIImage systemImageNamed:@"sun.max"] atIndex:1 animated:NO];
    [self.themeSegment insertSegmentWithImage:[UIImage systemImageNamed:@"moon"] atIndex:2 animated:NO];
    [[ThemeManager themeManager] updateSegmentedControl:self.themeSegment];
    self.themeSegment.selectedSegmentIndex = [@[ThemeStyleAuto, ThemeStyleLight, ThemeStyleDark] indexOfObject:[ThemeManager themeManager].theme];

    self.themeSegment.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [cell.contentView addSubview:self.themeSegment];

    return cell;
}

@end
