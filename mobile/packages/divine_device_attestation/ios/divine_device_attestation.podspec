#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint divine_device_attestation.podspec` to validate it.
#
Pod::Spec.new do |s|
  s.name             = 'divine_device_attestation'
  s.version          = '0.0.1'
  s.summary          = "Divine's account-scoped Apple App Attest integration."
  s.description      = <<-DESC
Mints account-scoped App Attest payloads for Divine video publishing.
                       DESC
  s.homepage         = 'https://divine.video'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Divine' => 'support@divine.video' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # App Attest key handles are cached in UserDefaults, one of Apple's
  # required-reason APIs. An SDK cannot rely on the host app's manifest, so
  # this bundle declares its own. CA92.1: UserDefaults.standard, the app's own
  # defaults domain, accessible only to this app.
  s.resource_bundles = {'divine_device_attestation_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
