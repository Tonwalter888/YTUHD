#import <substrate.h>
#import <sys/sysctl.h>
#import <version.h>
#import "Header.h"

extern "C" {
    BOOL UseVP9orAV1();
    BOOL AllVP9();
    int DecodeThreads();
    BOOL SkipLoopFilter();
    BOOL LoopFilterOptimization();
    BOOL RowThreading();
    BOOL AutoReload();
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

%hook MLInnerTubePlayerConfig

- (id)initWithPlayerConfig:(id)arg1 IOSPlayerConfig:(id)arg2 IOSShaderConfig:(id)arg3 HLSProxyConfig:(id)arg4 AVPlayerConfig:(id)arg5 hamplayerConfig:(id)arg6 autocropConfig:(id)arg7 videoToAudioItagMap:(id)arg8 DRMSessionID:(id)arg9 fairPlayConfig:(id)arg10 livePlayerConfig:(id)arg11 VRConfig:(id)arg12 stickyCeilingDuration:(double)arg13 offlineable:(BOOL)arg14 offline:(BOOL)arg15 dataSaverConfig:(id)arg16 audioConfig:(id)arg17 mediaCommonConfig:(id)arg18 varispeedAllowed:(BOOL)arg19 fetchManifestWhenNotActive:(BOOL)arg20 playbackStartConfig:(id)arg21 manifestlessWindowedLiveConfig:(id)arg22 qoeStatsClientConfig:(id)arg23 watchEndpointUstreamerConfig:(id)arg24 DAIType:(long long)arg25 {
    hookFormatsBase(arg6);
    return %orig;
}

%end

%hook MLHAMPlayerItem

- (id)initWithContext:(id)arg1 config:(id)arg2 onesieVideoData:(id)arg3 cache:(id)arg4 networkStatsProvider:(id)arg5 readaheadPolicy:(id)arg6 ustreamerRequestConfig:(id)arg7 loadRetryPolicy:(id)arg8 policyDelegate:(id)arg9 playerEventCenter:(id)arg10 QOEController:(id)arg11 hamplayerConfig:(id)arg12 watchEndpointUstreamerConfig:(id)arg13 contentType:(int)arg14 videoID:(id)arg15 {
    hookFormatsBase(arg12);
    return %orig;
}

- (void)onSelectableVideoFormats:(NSArray *)formats {
    hookFormatsBase([self valueForKey:@"_hamplayerConfig"]);
    %orig;
}

- (void)load {
    hookFormatsBase([self valueForKey:@"_hamplayerConfig"]);
    %orig;
}

- (void)loadWithInitialSeekRequired:(BOOL)initialSeekRequired initialSeekTime:(double)initialSeekTime {
    hookFormatsBase([self valueForKey:@"_hamplayerConfig"]);
    %orig;
}

%end

%hook MLABRPolicy

- (void)setFormats:(NSArray *)formats {
    hookFormatsBase([self valueForKey:@"_hamplayerConfig"]);
    %orig(filteredFormats(formats));
}

%end

%hook MLABRPolicyOld

- (void)setFormats:(NSArray *)formats {
    hookFormatsBase([self valueForKey:@"_hamplayerConfig"]);
    %orig(filteredFormats(formats));
}

%end

%hook MLABRPolicyNew

- (void)setFormats:(NSArray *)formats {
    hookFormatsBase([self valueForKey:@"_hamplayerConfig"]);
    %orig(filteredFormats(formats));
}

%end

%hook HAMDefaultABRPolicy

- (NSArray *)filterFormats:(NSArray *)formats {
    return filteredFormats(%orig);
}

- (id)getSelectableFormatDataAndReturnError:(NSError **)error {
    [self setValue:@(NO) forKey:@"_postponePreferredFormatFiltering"];
    return filteredFormats(%orig);
}

- (void)setFormats:(NSArray *)formats {
    [self setValue:@(YES) forKey:@"_postponePreferredFormatFiltering"];
    %orig(filteredFormats(formats));
}

%end

%group AutoReloadVideo
%hook MLHAMQueuePlayer

- (void)setState:(NSInteger)state {
    %orig;
    NSTimer *bufferingTimer = nil;
    if (state == 5 || state == 6 || state == 8) {
        if (bufferingTimer) {
            [bufferingTimer invalidate];
            bufferingTimer = nil;
        }
        __weak typeof(self) weakSelf = self;
        bufferingTimer = [NSTimer scheduledTimerWithTimeInterval:5
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

%end

%hook YTColdConfig

- (BOOL)iosPlayerClientSharedConfigPopulateSwAv1MediaCapabilities {
    return !AllVP9();
}

- (BOOL)iosPlayerClientSharedConfigDisableLibvpxDecoder {
    return NO; // This won't work anymore with YouTube 20.47.3 and higher.
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

%hook MLHLSStreamSelector

- (void)didLoadHLSMasterPlaylist:(id)arg1 {
    %orig;
    MLHLSMasterPlaylist *playlist = [self valueForKey:@"_completeMasterPlaylist"];
    NSArray *remotePlaylists = [playlist remotePlaylists];
    [[self delegate] streamSelectorHasSelectableVideoFormats:remotePlaylists];
}

%end

%hook YTIIosOnesieHotConfig

%new(B@:)
- (BOOL)prepareVideoDecoder { 
    return YES; 
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
    if (!UseVP9orAV1()) return;
    %init;
    if (!IS_IOS_OR_NEWER(iOS_15_0)) {
        %init(Spoofing);
    }
    if (AutoReload()) {
        %init(AutoReloadVideo);
    }
}