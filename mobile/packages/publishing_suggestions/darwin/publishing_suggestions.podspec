#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint publishing_suggestions.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'publishing_suggestions'
  s.version          = '0.0.1'
  s.summary          = 'On-device publishing suggestions.'
  s.description      = <<-DESC
Flutter plugin providing local publishing suggestions using Vision and Foundation Models.
                       DESC
  s.homepage         = 'https://github.com/divinevideo/divine-mobile'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Divine' => 'dev@divine.video' }
  s.source           = { :path => '.' }
  s.source_files     = 'publishing_suggestions/Sources/publishing_suggestions/**/*'
  s.ios.dependency       'Flutter'
  s.osx.dependency       'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.swift_version    = '5.9'
  s.frameworks       = 'Vision'
  s.weak_frameworks = 'FoundationModels'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
