#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>
#import <YouTubeHeader/YTMainAppControlsOverlayView.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import "Header.h"

#define TweakKey @"YTUHD"

extern BOOL AutoReload();

NSTimer *bufferingTimer = nil;

@interface YTMainAppVideoPlayerOverlayViewController (YTUHD)
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
@end

@interface YTMainAppVideoPlayerOverlayView (YTUHD)
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@end

@interface YTInlinePlayerBarController : NSObject
@end

@interface YTInlinePlayerBarContainerView (YTUHD)
- (void)didPressYTUHDReload:(id)arg;
@end

@interface YTMainAppControlsOverlayView (YTUHD)
- (void)didPressYTUHDReload:(id)arg;
@end

@interface YTPlayerViewController (YTUHD)
- (void)didPressYTUHDReload;
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

%group Reload
%hook YTPlayerViewController
%new
- (void)didPressYTUHDReload {
    CGFloat OldTime = self.currentVideoMediaTime;
    YTSingleVideoController *video = (YTSingleVideoController *)[self valueForKey:@"_playbackController"];
    YTLocalPlaybackController *playbackController = (YTLocalPlaybackController *)video.delegate;
    [[%c(YTPlayerTapToRetryResponderEvent) eventWithFirstResponder:[playbackController parentResponder]] send];
    [self seekToTime:OldTime];
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
    YTMainAppVideoPlayerOverlayView *mainOverlayView = (YTMainAppVideoPlayerOverlayView *)self.superview;
    YTMainAppVideoPlayerOverlayViewController *mainOverlayController = (YTMainAppVideoPlayerOverlayViewController *)mainOverlayView.delegate;
    YTPlayerViewController *pvc = mainOverlayController.parentViewController;
    [pvc didPressYTUHDReload];
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
    YTInlinePlayerBarController *delegate = self.delegate;
    YTMainAppVideoPlayerOverlayViewController *_delegate = [delegate valueForKey:@"_delegate"];
    YTPlayerViewController *pvc = _delegate.parentViewController;
    [pvc didPressYTUHDReload];
}

%end
%end

%ctor {
    initYTVideoOverlay(TweakKey, @{
        AccessibilityLabelKey: @"YTUHDReloadButton",
        SelectorKey: @"didPressYTUHDReload:",
        ToggleKey: AddsReloadButtonKey
    });
    %init(Reload);
    %init(Top);
    %init(Bottom);
    if (AutoReload()) {
        %init(Auto);
    }
}
