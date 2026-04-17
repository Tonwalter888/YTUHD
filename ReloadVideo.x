#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
#import "Header.h"

#define TweakKey @"YTUHD"

extern BOOL AutoReload();

NSTimer *bufferingTimer = nil;

@interface YTInlinePlayerBarContainerView (YTUHD)
- (void)didPressYTUHDReload:(id)arg;
@end

@interface YTMainAppControlsOverlayView (YTUHD)
- (void)didPressYTUHDReload:(id)arg;
@end

static UIImage *reloadIcon() {
    YTIIcon *icon = [%c(YTIIcon) new];
    icon.iconType = 181;
    if ([icon respondsToSelector:@selector(iconImageWithColor:)]) {
        return [icon iconImageWithColor:[%c(YTColor) white1]];
    }
    if ([icon respondsToSelector:@selector(iconImageWithSelected:)]) {
        return [icon iconImageWithSelected:NO];
    }
    return nil;
}

%group Auto
%hook MLHAMQueuePlayer

- (void)setState:(NSInteger)state {
    %orig;
    if (state == 5 || state == 6 || state == 8) {
        if (bufferingTimer) {
            [bufferingTimer invalidate];
            bufferingTimer = nil;
        }
        __weak typeof(self) weakSelf = self;
        bufferingTimer = [NSTimer scheduledTimerWithTimeInterval:2.5
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

%group Top
%hook YTMainAppControlsOverlayView

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? reloadIcon() : %orig;
}

%new(v@:@)
- (void)didPressYTUHDReload:(id)arg {
    YTSingleVideoController *video = (YTSingleVideoController *)self.delegate;
    YTLocalPlaybackController *playbackController = (YTLocalPlaybackController *)video.delegate;
    [[%c(YTPlayerTapToRetryResponderEvent) eventWithFirstResponder:[playbackController parentResponder]] send];
}

%end
%end

%group Bottom
%hook YTInlinePlayerBarContainerView

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? reloadIcon() : %orig;
}

%new(v@:@)
- (void)didPressYTUHDReload:(id)arg {
    YTSingleVideoController *video = (YTSingleVideoController *)self.delegate;
    YTLocalPlaybackController *playbackController = (YTLocalPlaybackController *)video.delegate;
    [[%c(YTPlayerTapToRetryResponderEvent) eventWithFirstResponder:[playbackController parentResponder]] send];
}

%end
%end

%ctor {
    initYTVideoOverlay(TweakKey, @{
        AccessibilityLabelKey: @"YTUHDReloadButton",
        SelectorKey: @"didPressYTUHDReload:",
        ToggleKey: AddsReloadButtonKey
    });
    %init(Top);
    %init(Bottom);
    if (AutoReload()) {
        %init(Auto);
    }
}