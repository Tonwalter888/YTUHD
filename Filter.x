// Disables HDR
#import "Header.h"

extern BOOL DisablesHDR();
extern BOOL FixPlayback();

NSArray <MLFormat *> *filteredAlot(NSArray <MLFormat *> *sth) {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(MLFormat *format, NSDictionary *bindings) {
        if (![format isKindOfClass:%c(MLFormat)]) return YES;
        NSString *qualityLabel = [format qualityLabel];
        BOOL isHDR = [qualityLabel containsString:@"HDR"];
        if (DisablesHDR()) {
            return !isHDR;
        }
        return YES;
    }];
    return [sth filteredArrayUsingPredicate:predicate];
}

%hook YTHotConfig
- (BOOL)iosPlayerClientSharedConfigDisableServerDrivenAbr { return YES; }
- (BOOL)iosPlayerClientSharedConfigPostponeCabrPreferredFormatFiltering { return YES; }
%end

%hook MLABRPolicy
- (void)setFormats:(NSArray *)formats { %orig(filteredAlot(formats)); }
%end

%hook MLABRPolicyOld
- (void)setFormats:(NSArray *)formats { %orig(filteredAlot(formats)); }
%end

%hook MLABRPolicyNew
- (void)setFormats:(NSArray *)formats { %orig(filteredAlot(formats)); }
%end

%hook HAMDefaultABRPolicy

- (NSArray *)filterFormats:(NSArray *)formats { return filteredAlot(%orig); }

- (id)getSelectableFormatDataAndReturnError:(NSError **)error {
    [self setValue:@(NO) forKey:@"_postponePreferredFormatFiltering"];
    return filteredAlot(%orig);
}

- (void)setFormats:(NSArray *)formats {
    [self setValue:@(YES) forKey:@"_postponePreferredFormatFiltering"];
    %orig(filteredAlot(formats));
}

%end

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

%ctor {
    if (FixPlayback() || !DisablesHDR()) return;
    %init;
}