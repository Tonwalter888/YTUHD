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
