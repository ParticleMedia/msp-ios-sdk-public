#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "MSPCore.h"

FOUNDATION_EXPORT double MSPCoreVersionNumber;
FOUNDATION_EXPORT const unsigned char MSPCoreVersionString[];

