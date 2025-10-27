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

// Remove any <= 1080p VP9 formats if AllVP9 is disabled
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

NSTimer *bufferingTimer = nil;

// Associated object key for NSTimer
static const void *kYTBufferingTimerKey = &kYTBufferingTimerKey;

static inline NSTimer *YT_GetTimer(id player) {
    return (NSTimer *)objc_getAssociatedObject(player, kYTBufferingTimerKey);
}

static inline void YT_SetTimer(id player, NSTimer *timer) {
    objc_setAssociatedObject(player, kYTBufferingTimerKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%hook MLHAMQueuePlayer

- (void)setState:(NSInteger)state {
    %orig;

    BOOL isBuffering = (state == 5 || state == 6 || state == 8);

    // Cancel old timer
    NSTimer *existing = YT_GetTimer(self);
    if (existing) {
        [existing invalidate];
        YT_SetTimer(self, nil);
    }

    if (!isBuffering) return;

    __weak typeof(self) weakSelf = self;
    NSTimer *t = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                  repeats:NO
                                                    block:^(__unused NSTimer *timer) {
        __strong typeof(weakSelf) selfStrong = weakSelf;
        YT_SetTimer(selfStrong, nil);
        if (!selfStrong) return;

        // Try get currentTime
        CMTime currentTime = kCMTimeZero;
        SEL currentTimeSel = @selector(currentTime);
        if ([selfStrong respondsToSelector:currentTimeSel]) {
            currentTime = ((CMTime (*)(id, SEL))objc_msgSend)(selfStrong, currentTimeSel);
        }

        // Seek logic:
        // - If at 0:00 → jump forward 0.01s
        // - Else → rewind back 0.01s
        CMTime seekTime;
        Float64 seconds = CMTimeGetSeconds(currentTime);
        if (seconds < 0.1) {
            seekTime = CMTimeMakeWithSeconds(0.01, NSEC_PER_SEC);
        } else {
            seekTime = CMTimeMakeWithSeconds(seconds - 0.01, NSEC_PER_SEC);
        }

        SEL seekSel = @selector(seekToTime:completionHandler:);
        if ([selfStrong respondsToSelector:seekSel]) {
            ((void (*)(id, SEL, CMTime, id))objc_msgSend)(selfStrong,
                                                          seekSel,
                                                          seekTime,
                                                          nil);
        }

        // Retry event
        id video = nil;
        if ([selfStrong respondsToSelector:@selector(delegate)]) {
            video = ((id (*)(id, SEL))objc_msgSend)(selfStrong, @selector(delegate));
        }

        id playbackController = nil;
        if (video && [video respondsToSelector:@selector(delegate)]) {
            playbackController = ((id (*)(id, SEL))objc_msgSend)(video, @selector(delegate));
        }

        id firstResponder = nil;
        SEL parentSel = @selector(parentResponder);
        if (playbackController && [playbackController respondsToSelector:parentSel]) {
            firstResponder = ((id (*)(id, SEL))objc_msgSend)(playbackController, parentSel);
        } else if (video && [video respondsToSelector:parentSel]) {
            firstResponder = ((id (*)(id, SEL))objc_msgSend)(video, parentSel);
        }

        Class RetryEvt = objc_getClass("YTPlayerTapToRetryResponderEvent");
        if (RetryEvt &&
            firstResponder &&
            [RetryEvt respondsToSelector:@selector(eventWithFirstResponder:)]) {

            id evt = ((id (*)(id, SEL, id))objc_msgSend)(RetryEvt,
                                                         @selector(eventWithFirstResponder:),
                                                         firstResponder);

            if (evt && [evt respondsToSelector:@selector(send)]) {
                ((void (*)(id, SEL))objc_msgSend)(evt, @selector(send));
            }
        }
    }];

    YT_SetTimer(self, t);
}

%end

// %hook MLHAMPlayerItem

// - (void)load {
//     hookFormatsBase([self valueForKey:@"_hamplayerConfig"]);
//     %orig;
// }

// - (void)loadWithInitialSeekRequired:(BOOL)initialSeekRequired initialSeekTime:(double)initialSeekTime {
//     hookFormatsBase([self valueForKey:@"_hamplayerConfig"]);
//     %orig;
// }

// %end

%hook YTIHamplayerHotConfig

%new(i@:)
- (int)libvpxDecodeThreads {
    return DecodeThreads();
}

%new(B@:)
- (BOOL)libvpxRowThreading {
    return RowThreading();
}

%new(B@:)
- (BOOL)libvpxSkipLoopFilter {
    return SkipLoopFilter();
}

%new(B@:)
- (BOOL)libvpxLoopFilterOptimization {
    return LoopFilterOptimization();
}

%end

%hook YTColdConfig

- (BOOL)iosPlayerClientSharedConfigPopulateSwAv1MediaCapabilities {
    return YES;
}

%end

%hook YTHotConfig

- (BOOL)iosPlayerClientSharedConfigDisableServerDrivenAbr {
    return YES;
}

- (BOOL)iosPlayerClientSharedConfigPostponeCabrPreferredFormatFiltering {
    return YES;
}

- (BOOL)iosPlayerClientSharedConfigHamplayerPrepareVideoDecoderForAvsbdl {
    return YES;
}

- (BOOL)iosPlayerClientSharedConfigHamplayerAlwaysEnqueueDecodedSampleBuffersToAvsbdl {
    return YES;
}

%end

// %hook HAMDefaultABRPolicy

// - (id)getSelectableFormatDataAndReturnError:(NSError **)error {
//     @try {
//         HAMDefaultABRPolicyConfig config = MSHookIvar<HAMDefaultABRPolicyConfig>(self, "_config");
//         config.softwareAV1Filter.maxArea = MAX_PIXELS;
//         config.softwareAV1Filter.maxFPS = MAX_FPS;
//         config.softwareVP9Filter.maxArea = MAX_PIXELS;
//         config.softwareVP9Filter.maxFPS = MAX_FPS;
//         MSHookIvar<HAMDefaultABRPolicyConfig>(self, "_config") = config;
//     } @catch (id ex) {}
//     return %orig;
// }

// - (void)setFormats:(NSArray *)formats {
//     @try {
//         HAMDefaultABRPolicyConfig config = MSHookIvar<HAMDefaultABRPolicyConfig>(self, "_config");
//         config.softwareAV1Filter.maxArea = MAX_PIXELS;
//         config.softwareAV1Filter.maxFPS = MAX_FPS;
//         config.softwareVP9Filter.maxArea = MAX_PIXELS;
//         config.softwareVP9Filter.maxFPS = MAX_FPS;
//         MSHookIvar<HAMDefaultABRPolicyConfig>(self, "_config") = config;
//     } @catch (id ex) {}
//     %orig;
// }

// %end

%hook MLHLSStreamSelector

- (void)didLoadHLSMasterPlaylist:(id)arg1 {
    %orig;
    MLHLSMasterPlaylist *playlist = [self valueForKey:@"_completeMasterPlaylist"];
    NSArray *remotePlaylists = [playlist remotePlaylists];
    [[self delegate] streamSelectorHasSelectableVideoFormats:remotePlaylists];
}

%end

%group Spoofing

%hook UIDevice

- (NSString *)systemVersion {
    return @"15.8.5";
}

%end

%hook NSProcessInfo

- (NSOperatingSystemVersion)operatingSystemVersion {
    NSOperatingSystemVersion version;
    version.majorVersion = 15;
    version.minorVersion = 8;
    version.patchVersion = 5;
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

%ctor {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        DecodeThreadsKey: @2
    }];
    if (!UseVP9()) return;
    %init;
    if (!IS_IOS_OR_NEWER(iOS_15_0)) {
        %init(Spoofing);
    }
}
