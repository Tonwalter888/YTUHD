#import <PSHeader/Misc.h>
#import <YouTubeHeader/YTHotConfig.h>
#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import "Header.h"

#define LOC(x) [tweakBundle localizedStringForKey:x value:nil table:nil]

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
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"YTUHD" ofType:@"bundle"];
        bundle = [NSBundle bundleWithPath:tweakBundlePath ?: PS_ROOT_PATH_NS(@"/Library/Application Support/YTUHD.bundle")];
    });
    return bundle;
}

// Create a new section called "YTUHD"
static YTSettingsSectionItem *createYTUHDSection(YTSettingsViewController *vc)
{
    NSBundle *bundle = YTUHDBundle();
    Class Item = %c(YTSettingsSectionItem);
    NSMutableArray *rows = [NSMutableArray array];

    // Use VP9
    YTSettingsSectionItem *vp9 =
        [Item switchItemWithTitle:LOC(@"USE_VP9")
                titleDescription:LOC(@"USE_VP9_DESC")
            accessibilityIdentifier:nil
                          switchOn:UseVP9()
                      switchBlock:^BOOL(YTSettingsCell *cell, BOOL enabled) {
                          [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:UseVP9Key];
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
                      switchBlock:^BOOL(YTSettingsCell *cell, BOOL enabled) {
                          [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:AllVP9Key];
                          return YES;
                      }
                   settingItemId:0];
    [rows addObject:allVP9];

    // Decode Threads
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
                YTSettingsSectionItem *choice =
                    [Item checkmarkItemWithTitle:[NSString stringWithFormat:@"%d", i]
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
    return [Item itemWithTitle:@"YTUHD"
               titleDescription:@"Ultra HD + Codec Enhancements"
       accessibilityIdentifier:nil
                   detailItems:rows];
}

%hook YTSettingsViewController

- (void)setSectionItems:(NSArray<YTSettingsSectionItem *> *)sectionItems
             forCategory:(NSInteger)category
                    title:(NSString *)title
          titleDescription:(NSString *)titleDescription
             headerHidden:(BOOL)headerHidden
{
    NSMutableArray *mutable = [sectionItems mutableCopy] ?: [NSMutableArray array];
    // Add YTUHD section
    YTSettingsSectionItem *section = createYTUHDSection(self);
    [mutable addObject:section];
    %orig(mutable, category, title, titleDescription, headerHidden);
}

- (void)setSectionItems:(NSArray<YTSettingsSectionItem *> *)sectionItems
             forCategory:(NSInteger)category
                    title:(NSString *)title
                     icon:(YTIIcon *)icon
          titleDescription:(NSString *)titleDescription
             headerHidden:(BOOL)headerHidden
{
    NSMutableArray *mutable = [sectionItems mutableCopy] ?: [NSMutableArray array];
    YTSettingsSectionItem *section = createYTUHDSection(self);
    [mutable addObject:section];
    %orig(mutable, category, title, icon, titleDescription, headerHidden);
}

%end