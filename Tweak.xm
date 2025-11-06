#import <substrate.h>
#import <sys/sysctl.h>
#import <version.h>
#import "Header.h"

extern "C" {
    BOOL UseVP9();
    int DecodeThreads();
}

NSArray <MLFormat *> *filteredFormats(NSArray <MLFormat *> *formats) {
    return formats;
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

static BOOL gYTUHD_HasHighRes = NO;
static BOOL ytuhd_formatsContainHighRes(NSArray<MLFormat *> *formats) {
    for (id f in formats) {
        if ([f respondsToSelector:@selector(qualityLabel)]) {
            NSString *ql = [(MLFormat *)f qualityLabel];
            if ([ql hasPrefix:@"2160p"] || [ql hasPrefix:@"1440p"]) {
                return YES;
            }
        }
        // (Optional) fallback by dimensions if exposed:
        if ([f respondsToSelector:@selector(width)] && [f respondsToSelector:@selector(height)]) {
            NSInteger w = (NSInteger)[(MLFormat *)f performSelector:@selector(width)];
            NSInteger h = (NSInteger)[(MLFormat *)f performSelector:@selector(height)];
            if (h >= 1440 || w >= 2560) return YES;
        }
    }
    return NO;
}

%hook MLABRPolicy
- (void)setFormats:(NSArray *)formats {
    gYTUHD_HasHighRes = ytuhd_formatsContainHighRes(formats);
    hookFormats(self);
    %orig(filteredFormats(formats));
}
%end

%hook MLABRPolicyOld
- (void)setFormats:(NSArray *)formats {
    gYTUHD_HasHighRes = ytuhd_formatsContainHighRes(formats);
    hookFormats(self);
    %orig(filteredFormats(formats));
}
%end

%hook MLABRPolicyNew
- (void)setFormats:(NSArray *)formats {
    gYTUHD_HasHighRes = ytuhd_formatsContainHighRes(formats);
    hookFormats(self);
    %orig(filteredFormats(formats));
}
%end

NSTimer *bufferingTimer = nil;

%hook MLHAMQueuePlayer

- (void)setState:(NSInteger)state {
    %orig;
    if (state == 5 || state == 6 || state == 8) {
        if (bufferingTimer) {
            [bufferingTimer invalidate];
            bufferingTimer = nil;
        }
        __weak typeof(self) weakSelf = self;
        NSTimeInterval waitTime = gYTUHD_HasHighRes ? 10.0 : 2.0;
        bufferingTimer = [NSTimer scheduledTimerWithTimeInterval:waitTime
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

%hook MLHAMPlayerItem

- (void)load {
    hookFormatsBase([self valueForKey:@"_hamplayerConfig"]);
    %orig;
}

- (void)loadWithInitialSeekRequired:(BOOL)initialSeekRequired initialSeekTime:(double)initialSeekTime {
    hookFormatsBase([self valueForKey:@"_hamplayerConfig"]);
    %orig;
}

%end

%hook YTIHamplayerHotConfig

%new(i@:)
- (int)libvpxDecodeThreads {
    return DecodeThreads();
}

%end

%hook YTColdConfig

- (BOOL)iosPlayerClientSharedConfigPopulateSwAv1MediaCapabilities {
    return YES;
}

- (BOOL)iosPlayerClientSharedConfigDisableLibvpxDecoder {
    return NO;
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

@interface HAMDefaultABRPolicy : NSObject
@end

%hook HAMDefaultABRPolicy

- (id)getSelectableFormatDataAndReturnError:(NSError **)error {
    [self setValue:@(NO) forKey:@"_postponePreferredFormatFiltering"];
    return filteredFormats(%orig);
}

- (void)setFormats:(NSArray *)formats {
    [self setValue:@(YES) forKey:@"_postponePreferredFormatFiltering"];
    %orig(filteredFormats(formats));
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
