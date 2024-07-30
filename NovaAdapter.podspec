

Pod::Spec.new do |spec|

  

  spec.name         = "NovaAdapter"
  spec.version      = "0.0.22"
  spec.summary      = "an adapter for Google SDK"
  spec.description  = "an adapter for Google SDK for MSP S2S"

  spec.homepage     = "https://github.com/aimsp/msp-ios-sdk/GoogleAdapter"
 
  spec.license      = "Copyright"
  
  #

  spec.author             = { "huanzhiNB" => "huanzhi.zhang@newsbreak.com" }
  # Or just: spec.author    = "huanzhiNB"
  # spec.authors            = { "huanzhiNB" => "huanzhi.zhang@newsbreak.com" }
  # spec.social_media_url   = "https://twitter.com/huanzhiNB"

  # spec.platform     = :ios
  # spec.platform     = :ios, "5.0"

  #  When using multiple platforms
  # spec.ios.deployment_target = "5.0"
  # spec.osx.deployment_target = "10.7"
  # spec.watchos.deployment_target = "2.0"
  # spec.tvos.deployment_target = "9.0"
  # spec.visionos.deployment_target = "1.0"


  # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Specify the location from where the source should be retrieved.
  #  Supports git, hg, bzr, svn and HTTP.
  #

  spec.source       = { :git => "https://github.com/huanzhiNB/msp-ios-sdk-public.git", :tag => "#{spec.version}" }

  spec.ios.deployment_target = '13.0'


  spec.source_files  = "NovaAdapter/NovaAdapter/**/*.{h,m,swift}"
  spec.exclude_files = "Classes/Exclude"

  #spec.dependency 'Google-Mobile-Ads-SDK', "10.14.0"
  spec.dependency 'MSPSharedLibraries', '0.0.19'


  spec.vendored_frameworks= "NovaAdapter/NovaCore.xcframework"

  spec.pod_target_xcconfig = { 'VALID_ARCHS' => 'x86_64 armv7 arm64' }
  spec.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }

  spec.static_framework = true
  # ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  A list of resources included with the Pod. These are copied into the
  #  target bundle with a build phase script. Anything else will be cleaned.
  #  You can preserve files from being cleaned, please don't preserve
  #  non-essential files like tests, examples and documentation.
  #

  # spec.resource  = "icon.png"
  # spec.resources = "Resources/*.png"

  # spec.preserve_paths = "FilesToSave", "MoreFilesToSave"


  # ――― Project Linking ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Link your library with frameworks, or libraries. Libraries do not include
  #  the lib prefix of their name.
  #

  # spec.framework  = "SomeFramework"
  # spec.frameworks = "SomeFramework", "AnotherFramework"

  # spec.library   = "iconv"
  # spec.libraries = "iconv", "xml2"


  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  If your library depends on compiler flags you can set them in the xcconfig hash
  #  where they will only apply to your library. If you depend on other Podspecs
  #  you can include multiple dependencies to ensure it works.

  # spec.requires_arc = true

  # spec.xcconfig = { "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2" }
  # spec.dependency "JSONKit", "~> 1.4"

end
