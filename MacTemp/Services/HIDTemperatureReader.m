#import "HIDTemperatureReader.h"
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>

typedef struct __IOHIDEvent *IOHIDEventRef;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
extern IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type, int32_t options, int64_t timestamp);
extern double IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

static const int64_t TemperatureEventType = 15;
static const int32_t TemperatureEventField = 15 << 16;

@implementation HIDTemperatureReader

+ (NSArray<NSDictionary<NSString *, id> *> *)readSensors {
    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (client == NULL) {
        return @[];
    }

    NSDictionary *matching = @{
        @"PrimaryUsagePage": @0xff00,
        @"PrimaryUsage": @5
    };
    IOHIDEventSystemClientSetMatching(client, (__bridge CFDictionaryRef)matching);

    CFArrayRef servicesReference = IOHIDEventSystemClientCopyServices(client);
    NSArray *services = CFBridgingRelease(servicesReference);
    NSMutableArray<NSDictionary<NSString *, id> *> *sensors = [NSMutableArray array];

    for (id serviceObject in services) {
        IOHIDServiceClientRef service = (__bridge IOHIDServiceClientRef)serviceObject;
        CFTypeRef productReference = IOHIDServiceClientCopyProperty(service, CFSTR("Product"));
        NSString *name = CFBridgingRelease(productReference);
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(service, TemperatureEventType, 0, 0);

        if (event == NULL) {
            continue;
        }

        double temperature = IOHIDEventGetFloatValue(event, TemperatureEventField);
        CFRelease(event);

        NSString *safeName = name.length > 0 ? name : @"Thermal sensor";
        if ([safeName.localizedLowercaseString containsString:@"tdev"] && temperature > 130) {
            temperature /= 256.0;
        }

        if (temperature > 0 && temperature < 150) {
            [sensors addObject:@{
                @"name": safeName,
                @"temperature": @(temperature)
            }];
        }
    }

    CFRelease(client);
    return sensors;
}

@end
