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

#define UseVP9Key @"EnableVP9"
#define AllVP9Key @"AllVP9"
#define DecodeThreadsKey @"VP9DecodeThreads"
#define SkipLoopFilterKey @"VP9SkipLoopFilter"
#define LoopFilterOptimizationKey @"VP9LoopFilterOptimization"
#define RowThreadingKey @"VP9RowThreading"

#endif
