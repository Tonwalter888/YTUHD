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

static const void *kYTBufferingTimerKey = &kYTBufferingTimerKey;

static inline NSTimer *YT_GetTimer(id player) {
    return (NSTimer *)objc_getAssociatedObject(player, kYTBufferingTimerKey);
}
static inline void YT_SetTimer(id player, NSTimer *timer) {
    objc_setAssociatedObject(player, kYTBufferingTimerKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// rewind helper
static inline void YT_RewindSmall(id player, Float64 offset) {
    if (!player) return;

    CMTime now = kCMTimeZero;
    if ([player respondsToSelector:@selector(currentTime)]) {
        now = ((CMTime (*)(id, SEL))objc_msgSend)(player, @selector(currentTime));
    }
    Float64 sec = CMTimeGetSeconds(now);
    if (!isfinite(sec) || sec < 0) sec = 0;

    Float64 target = sec - offset;
    if (target < 0) target = 0;
    CMTime seekTime = CMTimeMakeWithSeconds(target, NSEC_PER_SEC);

    if ([player respondsToSelector:@selector(seekToTime:completionHandler:)]) {
        ((void (*)(id, SEL, CMTime, id))objc_msgSend)(player,
                                                      @selector(seekToTime:completionHandler:),
                                                      seekTime,
                                                      nil);
    }
}

%hook MLHAMQueuePlayer

- (void)setState:(NSInteger)state {
    %orig;

    // cleanup old timer
    NSTimer *old = YT_GetTimer(self);
    if (old) { [old invalidate]; YT_SetTimer(self, nil); }

    // 5/6/8 → buffering/stalling
    if (state == 5 || state == 6 || state == 8) {
        __weak typeof(self) weakSelf = self;
        NSTimer *t = [NSTimer scheduledTimerWithTimeInterval:4.0
                                                      repeats:NO
                                                        block:^(__unused NSTimer *timer) {
            __strong typeof(weakSelf) selfStrong = weakSelf;
            YT_SetTimer(selfStrong, nil);
            if (!selfStrong) return;

            // rewind before reload
            YT_RewindSmall(selfStrong, 1.0);

            // trigger reload (Tap to retry)
            id video = nil;
            if ([selfStrong respondsToSelector:@selector(delegate)]) {
                video = ((id (*)(id, SEL))objc_msgSend)(selfStrong, @selector(delegate));
            }
            id playback = nil;
            if (video && [video respondsToSelector:@selector(delegate)]) {
                playback = ((id (*)(id, SEL))objc_msgSend)(video, @selector(delegate));
            }

            id firstResponder = nil;
            SEL parentSel = @selector(parentResponder);
            if (playback && [playback respondsToSelector:parentSel]) {
                firstResponder = ((id (*)(id, SEL))objc_msgSend)(playback, parentSel);
            } else if (video && [video respondsToSelector:parentSel]) {
                firstResponder = ((id (*)(id, SEL))objc_msgSend)(video, parentSel);
            }

            Class RetryEvt = objc_getClass("YTPlayerTapToRetryResponderEvent");
            if (RetryEvt && firstResponder &&
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

    // 2 → playing after reload
    else if (state == 2) {
        // rewind again once playback resumes
        YT_RewindSmall(self, 1.0);
    }
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
