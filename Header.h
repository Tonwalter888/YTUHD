#ifndef YTUHD_H_
#define YTUHD_H_

#import <Foundation/Foundation.h>
#import <YouTubeHeader/MLABRPolicyNew.h>
#import <YouTubeHeader/MLABRPolicyOld.h>
#import <YouTubeHeader/MLHAMPlayerItem.h>
#import <YouTubeHeader/MLHLSMasterPlaylist.h>
#import <YouTubeHeader/MLHLSStreamSelector.h>
#import <YouTubeHeader/HAMDefaultABRPolicy.h>
#import <YouTubeHeader/YTIHamplayerConfig.h>
#import <YouTubeHeader/YTIHamplayerStreamFilter.h>

#define IOS_BUILD "19H394"
#define MAX_FPS 60
#define MAX_PIXELS 8294400 // 3840 x 2160 (4K)

#define UseVP9orAV1Key @"EnableSWVP9orSWAV1"
#define AllVP9Key @"AllSWVP9"
#define DecodeThreadsKey @"SWVP9DecodeThreads"
#define SkipLoopFilterKey @"SWVP9SkipLoopFilter"
#define LoopFilterOptimizationKey @"SWVP9LoopFilterOptimization"
#define RowThreadingKey @"SWVP9RowThreading"

#endif
