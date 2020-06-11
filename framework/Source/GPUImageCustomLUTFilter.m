#import "GPUImageCustomLUTFilter.h"
#import "GPUImagePicture.h"
#import "GPUImageLookupFilter.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
#define NSUIImage UIImage
#else
#define NSUIImage NSImage
#endif

@implementation GPUImageCustomLUTFilter

- (id)initWithLUTName:(NSString *)lutName {
    if (!(self = [super init])) {
		return nil;
    }
    
    NSString *imageName = [NSString stringWithFormat:@"lookup_%@", lutName];
    NSUIImage *image = nil;
    
    for (int i = 0; i < 2; i++) {
        image = [NSUIImage imageNamed:imageName];
        if (image) {
            break;
        }
        else if (i == 0) {
            imageName = [NSString stringWithFormat:@"lookup_%@.jpg", lutName];
        }
    }
    
    NSAssert(image, @"You need to add lookup_%@ (jpg or png) to your app bundle!", lutName);
    
    lookupImageSource = [[GPUImagePicture alloc] initWithImage:image];
    GPUImageLookupFilter *lookupFilter = [[GPUImageLookupFilter alloc] init];
    [self addFilter:lookupFilter];
    
    [lookupImageSource addTarget:lookupFilter atTextureLocation:1];
    [lookupImageSource processImage];

    self.initialFilters = [NSArray arrayWithObjects:lookupFilter, nil];
    self.terminalFilter = lookupFilter;
    
    return self;
}

#pragma mark -
#pragma mark Accessors

@end
