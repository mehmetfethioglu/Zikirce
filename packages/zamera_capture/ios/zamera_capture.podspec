Pod::Spec.new do |s|
  s.name             = 'zamera_capture'
  s.version          = '0.1.7'
  s.summary          = 'Zamera native Camera2/AVFoundation capture, RAW ISP & Rust CIEDE2000 plugin.'
  s.description      = <<-DESC
Native Android (Camera2 + JNI Rust + LiteRT/MLKit) and iOS (AVFoundation + Vision + Rust C ABI) plugin for Zamera.
                       DESC
  s.homepage         = 'https://mehmetfethioglu.github.io/zamera-privacy/'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Akarworks' => 'theakar@windowslive.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'zamera_capture/Sources/zamera_capture/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '17.0'

  rust_staticlib = File.join(__dir__, 'zamera_capture/Frameworks/libzamera_core.a')
  xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  if File.exist?(rust_staticlib)
    s.vendored_libraries = 'zamera_capture/Frameworks/libzamera_core.a'
    xcconfig['OTHER_LDFLAGS'] = '$(inherited) -force_load "$(PODS_TARGET_SRCROOT)/zamera_capture/Frameworks/libzamera_core.a"'
  end
  s.pod_target_xcconfig = xcconfig
  s.swift_version = '5.0'
  s.resource_bundles = {
    'zamera_capture_privacy' => ['zamera_capture/Sources/zamera_capture/PrivacyInfo.xcprivacy']
  }
end
