// Remove Premium quality option and Disables HDR
#import "Header.h"

extern BOOL Premium();
extern BOOL DisablesHDR();
extern BOOL FixPlayback();

NSArray <MLFormat *> *filteredAlot(NSArray <MLFormat *> *sth) {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(MLFormat *format, NSDictionary *bindings) {
        if (![format isKindOfClass:%c(MLFormat)]) return YES;
        NSString *qualityLabel = [format qualityLabel];
        BOOL isPremiumQuality = [qualityLabel containsString:@"Premium"];
        BOOL isHDR = [qualityLabel containsString:@"HDR"];
        if (DisablesHDR() && Premium()) {
            return !isHDR && !isPremiumQuality;
        } else if (!DisablesHDR() && Premium()) {
            return !isPremiumQuality;
        } else if (DisablesHDR() && !Premium()) {
            return !isHDR;
        } else {
            return YES;
        }
    }];
    return [sth filteredArrayUsingPredicate:predicate];
}

%group Normal
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

%hook MLABRPolicy

- (void)setFormats:(NSArray *)formats {
    %orig(filteredAlot(sth));
}

%end

%hook MLABRPolicyOld

- (void)setFormats:(NSArray *)formats {
    %orig(filteredAlot(sth));
}

%end

%hook MLABRPolicyNew

- (void)setFormats:(NSArray *)formats {
    %orig(filteredAlot(sth));
}

%end

%hook HAMDefaultABRPolicy

- (NSArray *)filterFormats:(NSArray *)formats {
    return filteredAlot(%orig);
}

- (id)getSelectableFormatDataAndReturnError:(NSError **)error {
    [self setValue:@(NO) forKey:@"_postponePreferredFormatFiltering"];
    return filteredAlot(%orig);
}

- (void)setFormats:(NSArray *)formats {
    [self setValue:@(YES) forKey:@"_postponePreferredFormatFiltering"];
    %orig(filteredAlot(sth));
}

%end
%end

%group ForAVPIPPremium
%hook MLHLSStreamSelector

- (void)didLoadHLSMasterPlaylist:(id)arg1 {
    %orig;
    MLHLSMasterPlaylist *playlist = [self valueForKey:@"_completeMasterPlaylist"];
    NSArray *remotePlaylists = [playlist remotePlaylists];
    NSMutableArray *filter = [NSMutableArray array];
    for (MLFormat *formats in remotePlaylists) {
        NSString *label = [formats qualityLabel];
        if ([label containsString:@"Premium"]) continue;
        [filter addObject:formats];
    }
    [[self delegate] streamSelectorHasSelectableVideoFormats:filter];
}

%end
%end

%group ForAVPIPHDR
%hook MLHLSStreamSelector

- (void)didLoadHLSMasterPlaylist:(id)arg1 {
    %orig;
    MLHLSMasterPlaylist *playlist = [self valueForKey:@"_completeMasterPlaylist"];
    NSArray *remotePlaylists = [playlist remotePlaylists];
    NSMutableArray *filter = [NSMutableArray array];
    for (MLFormat *formats in remotePlaylists) {
        NSString *label = [formats qualityLabel];
        if ([label containsString:@"HDR"]) continue;
        [filter addObject:formats];
    }
    [[self delegate] streamSelectorHasSelectableVideoFormats:filter];
}

%end
%end

%group ForAVPIPBoth
%hook MLHLSStreamSelector

- (void)didLoadHLSMasterPlaylist:(id)arg1 {
    %orig;
    MLHLSMasterPlaylist *playlist = [self valueForKey:@"_completeMasterPlaylist"];
    NSArray *remotePlaylists = [playlist remotePlaylists];
    NSMutableArray *filter = [NSMutableArray array];
    for (MLFormat *formats in remotePlaylists) {
        NSString *label = [formats qualityLabel];
        if ([label containsString:@"HDR"]) continue;
        if ([label containsString:@"Premium"]) continue;
        [filter addObject:formats];
    }
    [[self delegate] streamSelectorHasSelectableVideoFormats:filter];
}

%end
%end

%ctor {
    if (DisablesHDR() && Premium()) {
        if (FixPlayback()) {
            %init(ForAVPIPPremium);
        } else {
            %init(ForAVPIPBoth);
            %init(Normal);
        }
    } else if (!DisablesHDR() && Premium()) {
        if (FixPlayback()) {
            %init(ForAVPIPPremium);
        } else {
            %init(Normal);
            %init(ForAVPIPPremium);
        }
    } else if (DisablesHDR() && !Premium()) {
        if (FixPlayback()) {
            return;
        } else {
            %init(ForAVPIPHDR);
            %init(Normal);
        }
    }
}