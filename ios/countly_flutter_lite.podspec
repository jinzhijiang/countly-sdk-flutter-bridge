Pod::Spec.new do |s|
  s.name             = 'countly_flutter_lite'
  s.version          = '26.1.0'
  s.summary          = 'Countly Flutter Lite native bridge for migration'
  s.description      = <<-DESC
A Flutter plugin shim to access legacy Countly native SDK storage for migration.
  DESC
  s.homepage         = 'https://count.ly'
  s.license          = { :file => '../../LICENSE' }
  s.author           = { 'Countly' => 'support@count.ly' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform     = :ios, '11.0'
  s.swift_version = '5.0'
end
