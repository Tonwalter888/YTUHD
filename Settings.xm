#import <PSHeader/Misc.h>
#import <VideoToolbox/VideoToolbox.h>
#import <YouTubeHeader/YTHotConfig.h>
#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import "Header.h"

#define LOC(x) [YTUHDBundle() localizedStringForKey:x value:nil table:nil]

BOOL UseVP9() { return [[NSUserDefaults standardUserDefaults] boolForKey:UseVP9Key]; }
BOOL AllVP9() { return [[NSUserDefaults standardUserDefaults] boolForKey:AllVP9Key]; }
int DecodeThreads() { return [[NSUserDefaults standardUserDefaults] integerForKey:DecodeThreadsKey]; }
BOOL SkipLoopFilter() { return [[NSUserDefaults standardUserDefaults] boolForKey:SkipLoopFilterKey]; }
BOOL LoopFilterOptimization() { return [[NSUserDefaults standardUserDefaults] boolForKey:LoopFilterOptimizationKey]; }
BOOL RowThreading() { return [[NSUserDefaults standardUserDefaults] boolForKey:RowThreadingKey]; }
BOOL ShowReloadButton() { return [[NSUserDefaults standardUserDefaults] boolForKey:@"YTUHDShowReloadButton"]; }

NSBundle *YTUHDBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"YTUHD" ofType:@"bundle"];
        bundle = [NSBundle bundleWithPath:tweakBundlePath ?: PS_ROOT_PATH_NS(@"/Library/Application Support/YTUHD.bundle")];
    });
    return bundle;
}

%hook YTSettingsViewController

- (void)viewDidLoad {
    %orig;

    // Create a brand new section for YTUHD
    NSMutableArray<YTSettingsSectionItem *> *items = [NSMutableArray array];
    Class ItemClass = %c(YTSettingsSectionItem);
    BOOL hasVP9 = VTIsHardwareDecodeSupported(kCMVideoCodecType_VP9);

    // --- VP9 toggle ---
    YTSettingsSectionItem *vp9 = [ItemClass switchItemWithTitle:LOC(@"USE_VP9")
        titleDescription:[NSString stringWithFormat:@"%@\n\n%@: %d",
                          LOC(@"USE_VP9_DESC"), LOC(@"HW_VP9_SUPPORT"), hasVP9]
        accessibilityIdentifier:nil
        switchOn:UseVP9()
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:UseVP9Key];
            return YES;
        }
        settingItemId:0];
    [items addObject:vp9];

    // --- All VP9 toggle ---
    YTSettingsSectionItem *allVP9 = [ItemClass switchItemWithTitle:LOC(@"ALL_VP9")
        titleDescription:LOC(@"ALL_VP9_DESC")
        accessibilityIdentifier:nil
        switchOn:AllVP9()
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:AllVP9Key];
            return YES;
        }
        settingItemId:0];
    [items addObject:allVP9];

    // --- Decode threads picker ---
    NSString *decodeThreadsTitle = LOC(@"DECODE_THREADS");
    YTSettingsSectionItem *decodeThreads = [ItemClass itemWithTitle:decodeThreadsTitle
        titleDescription:LOC(@"DECODE_THREADS_DESC")
        accessibilityIdentifier:nil
        detailTextBlock:^NSString *() {
            return [NSString stringWithFormat:@"%d", DecodeThreads()];
        }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            NSMutableArray<YTSettingsSectionItem *> *rows = [NSMutableArray array];
            for (int i = 1; i <= NSProcessInfo.processInfo.activeProcessorCount; ++i) {
                NSString *title = [NSString stringWithFormat:@"%d", i];
                NSString *titleDescription = i == 2 ? LOC(@"DECODE_THREADS_DEFAULT_VALUE") : nil;
                YTSettingsSectionItem *thread =
                  [ItemClass checkmarkItemWithTitle:title
                                   titleDescription:titleDescription
                                        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    [[NSUserDefaults standardUserDefaults] setInteger:i forKey:DecodeThreadsKey];
                    [self reloadData];
                    return YES;
                }];
                [rows addObject:thread];
            }
            NSUInteger index = DecodeThreads() - 1;
            if (index >= NSProcessInfo.processInfo.activeProcessorCount) {
                index = 1;
                [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:DecodeThreadsKey];
            }
            YTSettingsPickerViewController *picker =
              [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:decodeThreadsTitle
                                                        pickerSectionTitle:nil
                                                                     rows:rows
                                                        selectedItemIndex:index
                                                         parentResponder:[self parentResponder]];
            [self pushViewController:picker];
            return YES;
        }];
    [items addObject:decodeThreads];

    // --- Skip loop filter ---
    YTSettingsSectionItem *skipLoopFilter =
      [ItemClass switchItemWithTitle:LOC(@"SKIP_LOOP_FILTER")
                    titleDescription:nil
            accessibilityIdentifier:nil
                           switchOn:SkipLoopFilter()
                        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:SkipLoopFilterKey];
                            return YES;
                        }
                       settingItemId:0];
    [items addObject:skipLoopFilter];

    // --- Loop filter optimization ---
    YTSettingsSectionItem *loopFilterOptimization =
      [ItemClass switchItemWithTitle:LOC(@"LOOP_FILTER_OPTIMIZATION")
                    titleDescription:nil
            accessibilityIdentifier:nil
                           switchOn:LoopFilterOptimization()
                        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:LoopFilterOptimizationKey];
                            return YES;
                        }
                       settingItemId:0];
    [items addObject:loopFilterOptimization];

    // --- Row threading ---
    YTSettingsSectionItem *rowThreading =
      [ItemClass switchItemWithTitle:LOC(@"ROW_THREADING")
                    titleDescription:nil
            accessibilityIdentifier:nil
                           switchOn:RowThreading()
                        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:RowThreadingKey];
                            return YES;
                        }
                       settingItemId:0];
    [items addObject:rowThreading];

    // --- Show Reload Button ---
    YTSettingsSectionItem *reloadButton =
      [ItemClass switchItemWithTitle:LOC(@"SHOW_RELOAD_BUTTON")
                    titleDescription:LOC(@"SHOW_RELOAD_BUTTON_DESC")
            accessibilityIdentifier:nil
                           switchOn:ShowReloadButton()
                        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                            [[NSUserDefaults standardUserDefaults] setBool:enabled
                                                                  forKey:@"YTUHDShowReloadButton"];
                            return YES;
                        }
                       settingItemId:0];
    [items addObject:reloadButton];

    // Wrap into its own section header
    YTSettingsSectionItem *ytuhdSection =
      [%c(YTSettingsSectionItem) sectionItemWithTitle:@"YTUHD"
                                     titleDescription:@"Advanced video options"
                                                items:items];

    // Inject at the end of the settings list
    NSMutableArray *allSections = [self valueForKey:@"_sectionItems"];
    if (allSections) {
        [allSections addObject:ytuhdSection];
        [self reloadData];
    }
}
%end
