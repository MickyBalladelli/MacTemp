#import <Foundation/Foundation.h>

@interface HIDTemperatureReader : NSObject

+ (NSArray<NSDictionary<NSString *, id> *> *)readSensors;

@end
