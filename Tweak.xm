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

// -------------------- ctor --------------------
%ctor {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        DecodeThreadsKey: @2,
        @"YTUHDShowReloadButton": @NO
    }];

    if (!UseVP9()) return;
    %init;
    if (!IS_IOS_OR_NEWER(iOS_15_0)) {
        %init(Spoofing);
    }
}
