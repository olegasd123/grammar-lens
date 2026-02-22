Pod::Spec.new do |s|
  s.name             = 'llama_inference'
  s.version          = '0.1.0'
  s.summary          = 'FFI bindings for local llama.cpp inference.'
  s.description      = <<-DESC
Provides Flutter macOS integration metadata for the llama_inference package.
Native inference is loaded through Dart FFI.
                       DESC
  s.homepage         = 'https://grammarlens.app'
  s.license          = { :type => 'MIT' }
  s.author           = { 'GrammarLens' => 'dev@grammarlens.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
