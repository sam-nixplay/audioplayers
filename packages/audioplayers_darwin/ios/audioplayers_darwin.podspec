Pod::Spec.new do |s|
  s.name             = 'audioplayers_darwin'
  s.version          = '6.0.0'
  s.summary          = 'iOS, macOS, and tvOS implementation of audioplayers, a Flutter plugin to play multiple audio files simultaneously'
  s.description      = <<-DESC
  iOS, macOS, and tvOS implementation of audioplayers, a Flutter plugin to play multiple audio files simultaneously.
  DESC
  s.homepage         = 'https://github.com/bluefireteam/audioplayers'
  s.license          = { :type => 'BSD', :file => '../LICENSE' }
  s.author           = { 'Blue Fire' => 'contact@blue-fire.xyz' }
  s.source           = { :git => 'https://github.com/bluefireteam/audioplayers.git', :tag => s.version.to_s }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'

  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.14'
  s.tvos.deployment_target = '12.0'

  s.dependency 'Flutter'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.tvos.dependency 'Flutter'

  s.swift_version = '5.0'
end
