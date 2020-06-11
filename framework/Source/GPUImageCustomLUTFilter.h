#import "GPUImageFilterGroup.h"

@class GPUImagePicture;

// Note: If you want to use this effect you have to add lookup_???.png to your application bundle.

@interface GPUImageCustomLUTFilter : GPUImageFilterGroup
{
    GPUImagePicture *lookupImageSource;
}

- (id)initWithLUTName:(NSString *)lutName;

@end
