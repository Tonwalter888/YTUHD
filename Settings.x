#import <PSHeader/Misc.h>
#import <YouTubeHeader/YTHotConfig.h>
#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import "Header.h"

#define LOC(key) [tweakBundle localizedStringForKey:key value:nil table:nil]

BOOL UseVP9() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:UseVP9Key];
}

BOOL AllVP9() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:AllVP9Key];
}

int DecodeThreads() {
    return [[NSUserDefaults standardUserDefaults] integerForKey:DecodeThreadsKey];
}

NSBundle *YTUHDBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = [[NSBundle mainBundle] pathForResource:@"YTUHD" ofType:@"bundle"];
        bundle = [NSBundle bundleWithPath:path ?: PS_ROOT_PATH_NS(@"/Library/Application Support/YTUHD.bundle")];
    });
    return bundle;
}

// Create a new section called "YTUHD"
static NSArray<YTSettingsSectionItem *> *createYTUHDSection(YTSettingsViewController *vc)
{
    NSBundle *tweakBundle = YTUHDBundle();
    Class Item = %c(YTSettingsSectionItem);
    NSMutableArray *rows = [NSMutableArray array];
    // Section header item
    YTSettingsSectionItem *header =
        [Item itemWithTitle:@"YTUHD"
            titleDescription:@"Unlock 2K/4K video quality options"
        accessibilityIdentifier:nil
                 selectBlock:nil];
    [rows addObject:header];

    // Use VP9
    YTSettingsSectionItem *vp9 =
        [Item switchItemWithTitle:LOC(@"USE_VP9")
                 titleDescription:LOC(@"USE_VP9_DESC")
          accessibilityIdentifier:nil
                        switchOn:UseVP9()
                    switchBlock:^BOOL(YTSettingsCell *cell, BOOL en) {
                        [[NSUserDefaults standardUserDefaults] setBool:en forKey:UseVP9Key];
                        return YES;
                    }
                 settingItemId:0];
    [rows addObject:vp9];

    // All VP9
    YTSettingsSectionItem *allVP9 =
        [Item switchItemWithTitle:LOC(@"ALL_VP9")
                 titleDescription:LOC(@"ALL_VP9_DESC")
          accessibilityIdentifier:nil
                        switchOn:AllVP9()
                    switchBlock:^BOOL(YTSettingsCell *cell, BOOL en) {
                        [[NSUserDefaults standardUserDefaults] setBool:en forKey:AllVP9Key];
                        return YES;
                    }
                 settingItemId:0];
    [rows addObject:allVP9];

    // Decode threads picker
    NSString *title = LOC(@"DECODE_THREADS");
    YTSettingsSectionItem *decodeThreads =
        [Item itemWithTitle:title
           titleDescription:LOC(@"DECODE_THREADS_DESC")
        accessibilityIdentifier:nil
         detailTextBlock:^NSString *{
             return [NSString stringWithFormat:@"%d", DecodeThreads()];
         }
         selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger arg1) {
             NSMutableArray *choices = [NSMutableArray array];
             int cpu = NSProcessInfo.processInfo.activeProcessorCount;
             for (int i = 1; i <= cpu; i++) {
                 NSString *t = [NSString stringWithFormat:@"%d", i];
                 YTSettingsSectionItem *choice =
                     [Item checkmarkItemWithTitle:t
                                 titleDescription:(i == 2 ? LOC(@"DECODE_THREADS_DEFAULT_VALUE") : nil)
                                     selectBlock:^BOOL(YTSettingsCell *c, NSUInteger a) {
                                         [[NSUserDefaults standardUserDefaults] setInteger:i forKey:DecodeThreadsKey];
                                         [vc reloadData];
                                         return YES;
                                     }];
                 [choices addObject:choice];
             }
             NSUInteger index = MIN(MAX(DecodeThreads() - 1, 0), cpu - 1);
             YTSettingsPickerViewController *picker =
                 [[%c(YTSettingsPickerViewController) alloc]
                     initWithNavTitle:title
                    pickerSectionTitle:nil
                                 rows:choices
                    selectedItemIndex:index
                      parentResponder:[vc parentResponder]];
             [vc pushViewController:picker];
             return YES;
         }];
    [rows addObject:decodeThreads];
    return rows;
}

// Add YTUHD section to YouTube settings
%hook YTSettingsViewController

- (void)setSectionItems:(NSArray *)items
             forCategory:(NSInteger)category
                    title:(NSString *)title
          titleDescription:(NSString *)titleDesc
             headerHidden:(BOOL)hidden
{
    NSMutableArray *mut = [items mutableCopy] ?: [NSMutableArray array];
    NSArray *section = createYTUHDSection(self);
    [mut addObjectsFromArray:section];
    %orig(mut, category, title, titleDesc, hidden);
}

- (void)setSectionItems:(NSArray *)items
             forCategory:(NSInteger)category
                    title:(NSString *)title
                     icon:(YTIIcon *)icon
          titleDescription:(NSString *)titleDesc
             headerHidden:(BOOL)hidden
{
    NSMutableArray *mut = [items mutableCopy] ?: [NSMutableArray array];
    NSArray *section = createYTUHDSection(self);
    [mut addObjectsFromArray:section];
    %orig(mut, category, title, icon, titleDesc, hidden);
}

%end
