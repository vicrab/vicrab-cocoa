Pod::Spec.new do |s|
  s.name         = "Vicrab"
  s.version      = "0.3.0"
  s.summary      = "Vicrab client for cocoa"
  s.homepage     = "https://github.com/vicrab/vicrab-cocoa"
  s.license      = "MIT"
  s.author       = { "Vicrab" => "developer@vicrab.com" }
  s.authors      = "Vicrab"
  s.source       = { :git => "https://github.com/vicrab/vicrab-cocoa.git", :tag => s.version.to_s }

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.tvos.deployment_target = "9.0"
  s.watchos.deployment_target = "2.0"
  s.module_name  = "Vicrab"
  s.requires_arc = true
  s.frameworks = 'Foundation'
  s.libraries = 'z', 'c++'
  s.xcconfig = { 'GCC_ENABLE_CPP_EXCEPTIONS' => 'YES' }

  s.default_subspecs = ['Core']

  s.subspec 'Core' do |sp|
    sp.source_files = "Sources/Vicrab/**/*.{h,m}",
                      "Sources/VicrabCrash/**/*.{h,m,mm,c,cpp}"


  end
end