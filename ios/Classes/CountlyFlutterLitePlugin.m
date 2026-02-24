#import "CountlyFlutterLitePlugin.h"
#if __has_include(<countly_flutter_lite/countly_flutter_lite-Swift.h>)
#import <countly_flutter_lite/countly_flutter_lite-Swift.h>
#else
#import "countly_flutter_lite-Swift.h"
#endif

@implementation CountlyFlutterLitePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftCountlyFlutterLitePlugin registerWithRegistrar:registrar];
}
@end
