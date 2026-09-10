#
# Be sure to run `pod lib lint LibProofMode.podspec' to ensure this is a
# valid spec before submitting.
#


Pod::Spec.new do |s|
  s.name             = 'LibProofMode'
  s.version          = '0.1.11'
  s.summary          = 'LibProofMode is a native iOS Swift library for generating proof for media.'

  s.description      = <<-DESC
LibProofMode is a native iOS Swift library for generating proof for media.

It is provided as a CocoaPods library, so others can easily spin off of it
without the need to fork it. That way, spin-offs can easily stay up to date.
                       DESC

  s.homepage         = 'https://gitlab.com/guardianproject/proofmode/libproofmode-ios.git'
  s.license          = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
  s.author           = { 'Guardian Project' => 'support@guardianproject.info' }
  s.source           = { :git => 'https://gitlab.com/guardianproject/proofmode/libproofmode-ios.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/guardianproject'

  s.swift_version = '5.0'

  s.ios.deployment_target = '13.0'

  s.source_files = 'Classes/**/*'

  s.dependency 'ObjectivePGP', '~> 0.99'
  s.dependency 'DeviceKit', '~> 4.0'
  s.dependency 'LegacyUTType', '~> 0.1'

  s.source_files = 'Classes/**/*'

  s.default_subspec = :none

  # Divine-local addition (#8803): LibProofMode reads
  # URLResourceKey.contentModificationDateKey / .creationDateKey in
  # MediaItem.withData, which is one of Apple's required-reason APIs. The pod is
  # vendored here, so no upstream release will ship this manifest into Divine's
  # archive -- it has to be declared locally or the archive ships the API
  # undeclared. Reason C617.1: every path Divine feeds to MediaItem(mediaUrl:)
  # is a file the app itself wrote inside its own container.
  s.resource_bundles = {'LibProofMode_privacy' => ['Resources/PrivacyInfo.xcprivacy']}

  s.subspec 'PrivacyProtected' do |ss|
    ss.source_files = 'Classes/**/*'
    ss.resource_bundles = {'LibProofMode_privacy' => ['Resources/PrivacyInfo.xcprivacy']}

    ss.pod_target_xcconfig = {
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS': '$(inherited) PRIVACY_PROTECTED'
    }
  end
end
