#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint divine_camera.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'divine_camera'
  s.version          = '0.0.1'
  s.summary          = 'Camera plugin for iOS with AVFoundation-based recording and preview.'
  s.description      = <<-DESC
Flutter plugin providing native iOS camera operations including preview,
video recording, flash control, and audio device management.
                       DESC
  s.homepage         = 'https://github.com/divinevideo/divine-mobile'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Divine' => 'dev@divine.video' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Privacy manifest for camera and microphone access
  s.resource_bundles = {'divine_camera_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
