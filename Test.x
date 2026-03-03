// Adapt from YouPiP by PoomSmart
// Try to make this work in newer YT versions
// This research based on YT version 21.06.2
#import <Foundation/Foundation.h>
#import <version.h>
#import <YouTubeHeader/MLAVPlayer.h>
#import <YouTubeHeader/MLDefaultPlayerViewFactory.h>
#import <YouTubeHeader/MLHAMQueuePlayer.h>
#import <YouTubeHeader/MLPIPController.h>
#import <YouTubeHeader/MLPlayerPool.h>
#import <YouTubeHeader/MLPlayerPoolImpl.h>
#import <YouTubeHeader/MLVideoDecoderFactory.h>
#import <YouTubeHeader/YTAutonavEndscreenController.h>
#import <YouTubeHeader/YTBackgroundabilityPolicy.h>
#import <YouTubeHeader/YTHotConfig.h>
#import <YouTubeHeader/YTLiveWatchPlaybackOverlayView.h>
#import <YouTubeHeader/YTPlayerPIPController.h>
#import <YouTubeHeader/YTPlayerViewControllerConfig.h>
#import <YouTubeHeader/YTSystemNotifications.h>

extern BOOL Test();

static MLAVPlayer *makeAVPlayer(id self, MLVideo *video, MLInnerTubePlayerConfig *playerConfig, MLPlayerStickySettings *stickySettings) {
    BOOL externalPlaybackActive = [(MLAVPlayer *)[self valueForKey:@"_activePlayer"] externalPlaybackActive];
    MLAVPlayer *player = [[%c(MLAVPlayer) alloc] initWithVideo:video playerConfig:playerConfig stickySettings:stickySettings externalPlaybackActive:externalPlaybackActive];
    if (stickySettings)
        player.rate = stickySettings.rate;
    return player;
}

static void forceRenderViewTypeBase(YTIHamplayerConfig *hamplayerConfig) {
    if (!hamplayerConfig) return;
    hamplayerConfig.renderViewType = 2;
}

static void forceRenderViewTypeHot(YTIHamplayerHotConfig *hamplayerHotConfig) {
    if (!hamplayerHotConfig) return;
    hamplayerHotConfig.renderViewType = 2;
}

static void forceRenderViewType(YTHotConfig *hotConfig) {
    YTIHamplayerHotConfig *hamplayerHotConfig = [hotConfig hamplayerHotConfig];
    forceRenderViewTypeHot(hamplayerHotConfig);
}

%group FixPlayback
%hook MLPlayerPoolImpl

- (id)acquirePlayerForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig stickySettings:(MLPlayerStickySettings *)stickySettings {
    return makeAVPlayer(self, video, playerConfig, stickySettings);
}

- (id)acquirePlayerForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig stickySettings:(MLPlayerStickySettings *)stickySettings latencyLogger:(id)latencyLogger {
    return makeAVPlayer(self, video, playerConfig, stickySettings);
}

- (id)acquirePlayerForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig stickySettings:(MLPlayerStickySettings *)stickySettings latencyLogger:(id)latencyLogger reloadContext:(id)reloadContext {
    return makeAVPlayer(self, video, playerConfig, stickySettings);
}

- (id)acquirePlayerForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig stickySettings:(MLPlayerStickySettings *)stickySettings latencyLogger:(id)latencyLogger reloadContext:(id)reloadContext mediaPlayerResources:(id)mediaPlayerResources {
    return makeAVPlayer(self, video, playerConfig, stickySettings);
}

- (id)acquirePlayerForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig stickySettings:(MLPlayerStickySettings *)stickySettings latencyLogger:(id)latencyLogger reloadContext:(id)reloadContext mediaPlayerResources:(id)mediaPlayerResources recompositeProvider:(id)recompositeProvider {
    return makeAVPlayer(self, video, playerConfig, stickySettings);
} 

- (MLAVPlayerLayerView *)playerViewForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    MLDefaultPlayerViewFactory *factory = [self valueForKey:@"_playerViewFactory"];
    return [factory AVPlayerViewForVideo:video playerConfig:playerConfig];
}

- (MLAVPlayerLayerView *)playerViewForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig mediaPlayerResources:(id)mediaPlayerResources {
    MLDefaultPlayerViewFactory *factory = [self valueForKey:@"_playerViewFactory"];
    return [factory AVPlayerViewForVideo:video playerConfig:playerConfig];
}

- (BOOL)canQueuePlayerPlayVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    return NO;
}

- (BOOL)canQueuePlayerPlayVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig reloadContext:(id)reloadContext {
    return NO;
}

- (BOOL)canQueuePlayerPlayVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig reloadContext:(id)reloadContext error:(id *)error {
    return NO;
}

- (BOOL)canUsePlayerView:(id)playerView forPlayerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

%end

%hook MLPlayerPool

- (id)acquirePlayerForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig stickySettings:(MLPlayerStickySettings *)stickySettings {
    return makeAVPlayer(self, video, playerConfig, stickySettings);
}

- (id)acquirePlayerForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig stickySettings:(MLPlayerStickySettings *)stickySettings latencyLogger:(id)latencyLogger {
    return makeAVPlayer(self, video, playerConfig, stickySettings);
}

- (MLAVPlayerLayerView *)playerViewForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    MLDefaultPlayerViewFactory *factory = [self valueForKey:@"_playerViewFactory"];
    return [factory AVPlayerViewForVideo:video playerConfig:playerConfig];
}

- (BOOL)canUsePlayerView:(id)playerView forVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

- (BOOL)canQueuePlayerPlayVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    return NO;
}

%end

%hook MLDefaultPlayerViewFactory

- (id)hamPlayerViewForVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewType([self valueForKey:@"_hotConfig"]);
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

- (id)hamPlayerViewForPlayerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewType([self valueForKey:@"_hotConfig"]);
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

- (BOOL)canUsePlayerView:(id)playerView forVideo:(MLVideo *)video playerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

- (BOOL)canUsePlayerView:(id)playerView forPlayerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

%end

%hook MLVideoDecoderFactory

- (void)prepareDecoderForFormatDescription:(id)formatDescription delegateQueue:(id)delegateQueue {
    forceRenderViewTypeHot([self valueForKey:@"_hotConfig"]);
    %orig;
}

- (void)prepareDecoderForFormatDescription:(id)formatDescription setPixelBufferTypeOnlyIfEmpty:(BOOL)setPixelBufferTypeOnlyIfEmpty delegateQueue:(id)delegateQueue {
    forceRenderViewTypeHot([self valueForKey:@"_hotConfig"]);
    %orig;
}

%end

%hook YTGLMediaPlayerViewFactory

- (BOOL)canUsePlayerView:(id)playerView forPlayerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

- (id)hamPlayerViewForPlayerConfig:(MLInnerTubePlayerConfig *)playerConfig {
    forceRenderViewType([self valueForKey:@"_hotConfig"]);
    forceRenderViewTypeBase([playerConfig hamplayerConfig]);
    return %orig;
}

%end
%end

%ctor {
    if (Test()) {
        %init(FixPlayback)
    }
}