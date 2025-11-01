#import <substrate.h>
#import <sys/sysctl.h>
#import <version.h>
#import "Header.h"

extern "C" {
    BOOL UseVP9();
    BOOL AllVP9();
    int DecodeThreads();
    BOOL UseSDR();
    BOOL SkipLoopFilter();
    BOOL LoopFilterOptimization();
    BOOL RowThreading();
}

NSArray <MLFormat *> *filteredFormats(NSArray <MLFormat *> *formats) {
    @autoreleasepool {
        NSMutableArray *safeFormats = [formats mutableCopy];
        // Remove HDR color if Disable HDR is enabled
        if (UseSDR()) {
            NSMutableArray *sdrOnly = [NSMutableArray array];
            for (id f in safeFormats) {
                BOOL isHDR = NO;
                @try {
                    if ([f respondsToSelector:@selector(colorInfo)]) {
                        id colorInfo = [f colorInfo];
                        if (colorInfo) {
                            if ([colorInfo respondsToSelector:@selector(isHDRVideo)] &&
                                ((BOOL)[colorInfo performSelector:@selector(isHDRVideo)])) {
                                isHDR = YES;
                            } else if ([colorInfo respondsToSelector:@selector(hasHdr)] &&
                                       ((BOOL)[colorInfo performSelector:@selector(hasHdr)])) {
                                isHDR = YES;
                            } else if ([colorInfo respondsToSelector:@selector(colorTransfer)]) {
                                NSInteger transferValue = (NSInteger)[colorInfo performSelector:@selector(colorTransfer)];
                                if (transferValue > 1) isHDR = YES;
                            }
                        }
                    }
                    if (!isHDR && [f respondsToSelector:@selector(qualityLabel)]) {
                        NSString *label = [[f qualityLabel] lowercaseString];
                        if ([label containsString:@"hdr"]) {
                            isHDR = YES;
                        }
                    }
                } @catch (NSException *ex) {}
                if (!isHDR) {
                    [sdrOnly addObject:f];
                }
            }
            safeFormats = sdrOnly;
        }
        if (AllVP9()) {
            // If AllVP9 enabled → Force VP9 only
            NSMutableArray *vp9Only = [NSMutableArray array];
            for (MLFormat *format in safeFormats) {
                NSString *mime = [format MIMEType];
                if ([mime containsString:@"vp9"] || [mime containsString:@"vp09"]) {
                    [vp9Only addObject:format];
                }
            }
            return vp9Only;
        } else {
            // If AllVP9 disabled → Apply OG logic
            NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(MLFormat *format, NSDictionary *bindings) {
                NSString *qualityLabel = [format qualityLabel];
                BOOL isHighRes = [qualityLabel hasPrefix:@"2160p"] || [qualityLabel hasPrefix:@"1440p"];
                BOOL isVP9orAV1 = [[format MIMEType] videoCodec] == 'vp09' || [[format MIMEType] videoCodec] == 'av01';
                return (isHighRes && isVP9orAV1) || !isVP9orAV1;
            }];
            return [safeFormats filteredArrayUsingPredicate:predicate];
        }
    }
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

%hook MLHAMQueuePlayer

- (void)setState:(NSInteger)state {
    %orig;

    // Only reload video if AllVP9 is enabled
    if (!AllVP9()) return;

    if (state == 5 || state == 6 || state == 8) {
        if (bufferingTimer) {
            [bufferingTimer invalidate];
            bufferingTimer = nil;
        }
        __weak typeof(self) weakSelf = self;
        bufferingTimer = [NSTimer scheduledTimerWithTimeInterval:2
                                                         repeats:NO
                                                           block:^(NSTimer *timer) {
            bufferingTimer = nil;
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                YTSingleVideoController *video = (YTSingleVideoController *)strongSelf.delegate;
                YTLocalPlaybackController *playbackController = (YTLocalPlaybackController *)video.delegate;
                [[%c(YTPlayerTapToRetryResponderEvent) eventWithFirstResponder:[playbackController parentResponder]] send];
            }
        }];
    } else {
        if (bufferingTimer) {
            [bufferingTimer invalidate];
            bufferingTimer = nil;
        }
    }
}

%end

%hook YTIHamplayerConfig
- (BOOL)allowAdaptiveBitrate { 
    return NO;
}
- (BOOL)enableAdaptiveBitrate { 
    return NO; 
}

%end

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

- (BOOL)enableAdaptiveBitrate { 
    return NO; 
}

- (BOOL)useClientAbr { 
    return NO; 
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

- (BOOL)iosPlayerClientSharedConfigHamplayerDisableAbr {
    return YES;
}

- (BOOL)iosPlayerClientSharedConfigDisableAbrDuringPlayback {
    return YES;
}

- (BOOL)iosPlayerClientSharedConfigDisableAbrInGeneral {
    return YES;
}

%end

%hook YTHotConfigGroup
- (BOOL)hasClientAbrConfig { 
    return NO;
}

- (BOOL)shouldUseServerDrivenAbr {
    return NO;
}

%end

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
