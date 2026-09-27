Pod::Spec.new do |s|
  s.name             = 'divine_video_player'
  s.version          = '0.1.0'
  s.summary          = 'Multi-clip seamless video player for iOS and macOS.'
  s.description      = 'Multi-clip video player using AVFoundation.'
  s.homepage         = 'https://github.com/divinevideo/divine-mobile'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Divine Video' => 'dev@divinevideo.co' }
  s.source           = { :http => 'https://github.com/divinevideo/divine-mobile' }
  s.source_files     = 'divine_video_player/Sources/divine_video_player/**/*.swift'
  s.ios.dependency       'Flutter'
  s.osx.dependency       'FlutterMacOS'
  s.ios.deployment_target = '16.0'
  s.osx.deployment_target = '13.0'
  s.swift_version    = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }

  # Privacy manifest for the loop audio's host-clock scheduling
  s.resource_bundles = {'divine_video_player_privacy' => ['divine_video_player/Sources/divine_video_player/Resources/PrivacyInfo.xcprivacy']}
end
