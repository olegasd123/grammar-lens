Pod::Spec.new do |s|
  s.name             = 'platform_integration'
  s.version          = '0.1.0'
  s.summary          = 'macOS platform integration for GrammarLens.'
  s.description      = 'Accessibility API bridge, global hotkeys, and text field access for macOS.'
  s.homepage         = 'https://grammarlens.app'
  s.license          = { :type => 'MIT' }
  s.author           = { 'GrammarLens' => 'dev@grammarlens.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '13.0'
  s.swift_version    = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
