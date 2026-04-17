#ifndef YTUHD_H_
#define YTUHD_H_

#import <Foundation/Foundation.h>
#import <YouTubeHeader/MLFormat.h>
#import <YouTubeHeader/MLABRPolicyNew.h>
#import <YouTubeHeader/MLABRPolicyOld.h>
#import <YouTubeHeader/MLHAMPlayerItem.h>
#import <YouTubeHeader/MLHAMQueuePlayer.h>
#import <YouTubeHeader/MLHLSMasterPlaylist.h>
#import <YouTubeHeader/MLHLSStreamSelector.h>
#import <YouTubeHeader/HAMDefaultABRPolicy.h>
#import <YouTubeHeader/YTIHamplayerConfig.h>
#import <YouTubeHeader/YTIHamplayerStreamFilter.h>
#import <YouTubeHeader/YTLocalPlaybackController.h>
#import <YouTubeHeader/YTSingleVideoController.h>
#import <YouTubeHeader/YTPlayerTapToRetryResponderEvent.h>
#import <YouTubeHeader/YTIIcon.h>
#import <YouTubeHeader/YTColor.h>

#define IOS_BUILD "19H411" // iOS 15.8.7
#define MAX_FPS 60
#define MAX_PIXELS 8294400 // 3840 x 2160 (4K)

#define UseVP9orAV1Key @"YTUHDEnableSWVP9orSWAV1"
#define DecodeThreadsKey @"YTUHDSWVP9DecodeThreads"
#define SkipLoopFilterKey @"YTUDSWVP9SkipLoopFilter"
#define LoopFilterOptimizationKey @"YTUHDSWVP9LoopFilterOptimization"
#define RowThreadingKey @"YTUHDSWVP9RowThreading"
#define AutoReloadKey @"YTUHDReloadVideos"
#define AddsReloadButtonKey @"YTUHDReloadVideoButton"
#define CodecKey @"YTUHDSelectCodec"
#define FixPlaybackKey @"YTUHDFixPlaybackIssues"
#define PremiumKey @"YTUHDNoPremiumQuality"
#define DisablesHDRKey @"YTUHDRemoveHDR"

#endif