#import <VideoToolbox/VideoToolbox.h>

extern BOOL UseVP9();

#ifdef ENSUREUHD

typedef struct OpaqueVTVideoDecoder VTVideoDecoderRef;
extern OSStatus VTSelectAndCreateVideoDecoderInstance(CMVideoCodecType codecType, CFAllocatorRef allocator, CFDictionaryRef videoDecoderSpecification, VTVideoDecoderRef *decoderInstanceOut);

#endif

%ctor {
#ifdef ENSUREUHD
    CFMutableDictionaryRef payload = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    if (payload) {
        CFDictionarySetValue(payload, CFSTR("RequireHardwareAcceleratedVideoDecoder"), kCFBooleanTrue);
        CFDictionarySetValue(payload, CFSTR("AllowAlternateDecoderSelection"), kCFBooleanTrue);
        VTSelectAndCreateVideoDecoderInstance(kCMVideoCodecType_VP9, kCFAllocatorDefault, payload, NULL);
        CFRelease(payload);
    }
#endif
}
