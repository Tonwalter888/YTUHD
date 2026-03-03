#import <Foundation/Foundation.h>
#import <YouTubeHeader/MLAVPlayer.h>

extern BOOL Test();

%group BB
%hook YTIHamplayerConfig

- (BOOL)useSbdlRenderView { return NO; }
- (BOOL)disableResolveOverlappingQualitiesByCodec { return YES; }

%end

%hook MLAVPlayer

- (instancetype)initWithVideo:(MLVideo *)video
                 playerConfig:(MLInnerTubePlayerConfig *)playerConfig
               stickySettings:(MLPlayerStickySettings *)stickySettings
       externalPlaybackActive:(BOOL)externalPlaybackActive
{
    externalPlaybackActive = YES;   // spoof AirPlay
    return %orig(video, playerConfig, stickySettings, externalPlaybackActive);
}

%end
%end

%ctor {
    if (Test()) {
        %init(BB)
    }
}