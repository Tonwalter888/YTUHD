#import <substrate.h>
#import <sys/sysctl.h>
#import <version.h>
#import "Header.h"

extern "C" {
    BOOL UseVP9();
    BOOL AllVP9();
    int DecodeThreads();
    BOOL SkipLoopFilter();
    BOOL LoopFilterOptimization();
    BOOL RowThreading();
}

// -------------------- Format Filtering --------------------
NSArray <MLFormat *> *filteredFormats(NSArray <MLFormat *> *formats) {
    if (AllVP9()) return formats;
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(MLFormat *format, NSDictionary *bindings) {
        NSString *qualityLabel = [format qualityLabel];
        BOOL isHighRes = [qualityLabel hasPrefix:@"2160p"] || [qualityLabel hasPrefix:@"1440p"];
        BOOL isVP9orAV1 = [[format MIMEType] videoCodec] == 'vp09' || [[format MIMEType] videoCodec] == 'av01';
        return (isHighRes && isVP9orAV1) || !isVP9orAV1;
    }];
    return [formats filteredArrayUsingPredicate:predicate];
}

static void hookFormatsBase(YTIHamplayerConfig *config) {
    if ([config.videoAbrConfig respondsToSelector:@selector(setPreferSoftwareHdrOverHardwareSdr:)])
        config.videoAbrConfig.preferSoftwareHdrOverHardwareSdr = YES;
    if ([config respondsToSelector:@selector(setDisableResolveOverlappingQualitiesByCodec:)])
        config.disableResolveOverlappingQualitiesByCodec = NO;
    YTIHamplayerStreamFilter *filter = config.streamFilter;
    filter.enableVideoCodecSplicing = YES;
    filter.av1.maxArea = MAX_PIXELS;
    filter.av1.maxFps = MAX_FPS;
    filter.vp9.maxArea = MAX_PIXELS;
    filter.vp9.maxFps = MAX_FPS;
}

static void hookFormats(MLABRPolicy *self) {
    hookFormatsBase([self valueForKey:@"_hamplayerConfig"]);
}

%hook MLABRPolicy
- (void)setFormats:(NSArray *)formats {
    hookFormats(self);
    %orig(filteredFormats(formats));
}
%end

%hook MLABRPolicyOld
- (void)setFormats:(NSArray *)formats {
    hookFormats(self);
    %orig(filteredFormats(formats));
}
%end

%hook MLABRPolicyNew
- (void)setFormats:(NSArray *)formats {
    hookFormats(self);
    %orig(filteredFormats(formats));
}
%end

// -------------------- Hot/Cold Configs --------------------
%hook YTIHamplayerHotConfig
%new(i@:) - (int)libvpxDecodeThreads { return DecodeThreads(); }
%new(B@:) - (BOOL)libvpxRowThreading { return RowThreading(); }
%new(B@:) - (BOOL)libvpxSkipLoopFilter { return SkipLoopFilter(); }
%new(B@:) - (BOOL)libvpxLoopFilterOptimization { return LoopFilterOptimization(); }
%end

%hook YTColdConfig
- (BOOL)iosPlayerClientSharedConfigPopulateSwAv1MediaCapabilities { return YES; }
%end

%hook YTHotConfig
- (BOOL)iosPlayerClientSharedConfigDisableServerDrivenAbr { return YES; }
- (BOOL)iosPlayerClientSharedConfigPostponeCabrPreferredFormatFiltering { return YES; }
- (BOOL)iosPlayerClientSharedConfigHamplayerPrepareVideoDecoderForAvsbdl { return YES; }
- (BOOL)iosPlayerClientSharedConfigHamplayerAlwaysEnqueueDecodedSampleBuffersToAvsbdl { return YES; }
%end

%hook MLHLSStreamSelector
- (void)didLoadHLSMasterPlaylist:(id)arg1 {
    %orig;
    MLHLSMasterPlaylist *playlist = [self valueForKey:@"_completeMasterPlaylist"];
    NSArray *remotePlaylists = [playlist remotePlaylists];
    [[self delegate] streamSelectorHasSelectableVideoFormats:remotePlaylists];
}
%end

// -------------------- iOS Spoofing --------------------
%group Spoofing
%hook UIDevice
- (NSString *)systemVersion { return @"15.8.4"; }
%end
%hook NSProcessInfo
- (NSOperatingSystemVersion)operatingSystemVersion {
    NSOperatingSystemVersion version = {15, 8, 4};
    return version;
}
%end
%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (strcmp(name, "kern.osversion") == 0) {
        int ret = %orig;
        if (oldp) {
            strcpy((char *)oldp, IOS_BUILD);
            *oldlenp = strlen(IOS_BUILD);
        }
        return ret;
    }
    return %orig;
}
%end

// -------------------- Reload Button --------------------
#define ReloadTweakKey @"YTUHDReload"

@interface YTPlayerTapToRetryResponderEvent : NSObject
+ (instancetype)eventWithFirstResponder:(id)responder;
- (void)send;
@end

@interface YTMainAppVideoPlayerOverlayViewController (YTUHDReload)
@property (nonatomic, weak) YTPlayerViewController *parentViewController;
@end

@interface YTMainAppVideoPlayerOverlayView (YTUHDReload)
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@end

@interface YTMainAppControlsOverlayView (YTUHDReload)
@property (nonatomic, weak) YTPlayerViewController *playerViewController;
- (void)didPressYTUHDReload:(id)arg;
@end

@interface YTPlayerViewController (YTUHDReload)
- (void)didPressYTUHDReload;
@end

@interface YTInlinePlayerBarController : NSObject
@end

@interface YTInlinePlayerBarContainerView (YTUHDReload)
@property (nonatomic, strong) YTInlinePlayerBarController *delegate;
- (void)didPressYTUHDReload:(id)arg;
@end

static UIImage *reloadImage(NSString *qualityLabel) {
    return [%c(QTMIcon) tintImage:[UIImage systemImageNamed:@"arrow.clockwise"]
                              color:[%c(YTColor) white1]];
}

%group Reload

%hook YTMainAppControlsOverlayView
- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:ReloadTweakKey] ? reloadImage(@"3") : %orig;
}
%new(v@:@)
- (void)didPressYTUHDReload:(id)arg {
    YTMainAppVideoPlayerOverlayView *mainOverlayView = (YTMainAppVideoPlayerOverlayView *)self.superview;
    YTMainAppVideoPlayerOverlayViewController *mainOverlayController = (YTMainAppVideoPlayerOverlayViewController *)mainOverlayView.delegate;
    YTPlayerViewController *playerViewController = mainOverlayController.parentViewController;
    if (playerViewController) {
        [playerViewController didPressYTUHDReload];
    }
}
%end

%hook YTInlinePlayerBarContainerView
- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:ReloadTweakKey] ? reloadImage(@"3") : %orig;
}
%new(v@:@)
- (void)didPressYTUHDReload:(id)arg {
    YTInlinePlayerBarController *delegate = self.delegate;
    YTMainAppVideoPlayerOverlayViewController *_delegate = [delegate valueForKey:@"_delegate"];
    YTPlayerViewController *parentViewController = _delegate.parentViewController;
    if (parentViewController) {
        [parentViewController didPressYTUHDReload];
    }
}
%end
%end

// -------------------- ctor --------------------
%ctor {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        DecodeThreadsKey: @2
    }];
    if (!UseVP9()) return;
    %init;
    if (!IS_IOS_OR_NEWER(iOS_15_0)) {
        %init(Spoofing);
    }

    // Register Reload button
    initYTVideoOverlay(ReloadTweakKey, @{
        AccessibilityLabelKey: @"Reload Video",
        SelectorKey: @"didPressYTUHDReload:",
    });
    %init(Reload);
}

