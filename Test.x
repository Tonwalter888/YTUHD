#import <Foundation/Foundation.h>

extern BOOL Test();

%group BB
%hook YTIHamplayerConfig

- (BOOL)useSbdlRenderView { return NO; }
- (int)renderViewType { return 6; }
- (BOOL)disableResolveOverlappingQualitiesByCodec { return YES; }

%end
%end

%ctor {
    if (Test()) {
        %init(BB)
    }
}