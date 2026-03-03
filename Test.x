#import <Foundation/Foundation.h>

extern BOOL Test();

%group BB
%hook YTIHamplayerConfig

- (BOOL)useSbdlRenderView { return NO; }
- (int)renderViewType {
    int v = %orig;
    NSLog(@"[WATERDEV] renderViewType read = %d", v);
    return v;
}
- (BOOL)disableResolveOverlappingQualitiesByCodec { return YES; }

%end
%end

%ctor {
    if (Test()) {
        %init(BB)
    }
}