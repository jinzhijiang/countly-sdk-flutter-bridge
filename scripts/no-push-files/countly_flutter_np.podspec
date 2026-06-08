#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name = 'countly_flutter_np'
  s.version = '26.1.0'
  s.summary = 'Countly is an innovative, real-time, open source mobile analytics platform.'
  s.homepage = 'https://github.com/Countly/countly-sdk-flutter-bridge'
  s.social_media_url = 'https://twitter.com/gocountly'
  s.author = {'Countly' => 'hello@count.ly'}
  s.source = { :path => '.' }
  s.source_files = [
    'Classes/*.{h,m,swift}',
    'Classes/countly-sdk-ios/**/*.{h,m,swift}'
  ]
  s.exclude_files = [
    'Classes/countly-sdk-ios/Countly.xcodeproj/**/*',
    'Classes/countly-sdk-ios/CountlyTests/**/*',
    'Classes/countly-sdk-ios/Package.swift'
  ]
  s.public_header_files = 'Classes/CountlyFlutterPlugin.h'
  s.resource_bundles = {
    'countly_flutter_np_privacy' => ['Classes/countly-sdk-ios/PrivacyInfo.xcprivacy']
  }
  s.dependency 'Flutter'
  s.swift_version = '5.0'
  s.ios.deployment_target = '10.0'
  s.static_framework = true
end
