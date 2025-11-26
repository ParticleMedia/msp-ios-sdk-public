
# Uncomment the next line to define a global platform for your project
 platform :ios, '15.0'

workspace 'msp-ios-sdk'
install! 'cocoapods',
         :generate_multiple_pod_projects => true,
         :integrate_targets => false

# Only define the main app project - XcodeGen Core projects are for XCFramework building only
project 'Examples/MSPDemoApp/MSPDemoApp', 'Debug' => :debug, 'Release' => :release

# MSP DemoApp integration mode: cocoapods (default) or spm
demoapp_pod_configs = %w[Debug Release]
puts "[MSPDemoApp] Integrating CocoaPods dependencies for DemoApp target"

target 'MSPDemoApp' do
  project 'Examples/MSPDemoApp/MSPDemoApp'

  # Core modules (binary XCFrameworks)
  pod 'MSPiOSCore', :path => 'MSPiOSCore.podspec', :configurations => demoapp_pod_configs
  pod 'NovaCore', :path => 'NovaCore.podspec', :configurations => demoapp_pod_configs
  pod 'MSPCore', :path => 'MSPCore.podspec', :configurations => demoapp_pod_configs
  
  # Shared modules (abstraction layers)
  pod 'MSPGoogleAdsTypes', :path => 'MSPGoogleAdsTypes.podspec', :configurations => demoapp_pod_configs
  
  # Adapter modules (source pods)
  pod 'NovaAdapter', :path => 'NovaAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'MSPPrebidAdapter', :path => 'MSPPrebidAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'MSPGoogleAdapter', :path => 'MSPGoogleAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'MSPFacebookAdapter', :path => 'MSPFacebookAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'UnityAdapter', :path => 'UnityAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'InmobiAdapter', :path => 'InmobiAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'MobilefuseAdapter', :path => 'MobilefuseAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'MintegralAdapter', :path => 'MintegralAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'PubmaticAdapter', :path => 'PubmaticAdapter.podspec', :configurations => demoapp_pod_configs
  pod 'AmazonAdapter', :path => 'AmazonAdapter.podspec', :configurations => demoapp_pod_configs
  # SwiftProtobuf is now provided via XCFramework in MSPCore - removed from Podfile
  pod 'MSPSharedLibraries', :path => 'MSPSharedLibraries.podspec', :configurations => demoapp_pod_configs
  # MSPKingfisher replaces official Kingfisher pod to avoid SwiftVerifyEmittedModuleInterface errors
  pod 'MSPKingfisher', :path => 'ThirdParty/MSPKingfisher/MSPKingfisher.podspec', :configurations => demoapp_pod_configs
  # Lottie and Shimmer are needed by NovaCore at compile time
  pod 'lottie-ios', '~> 4.2', :configurations => demoapp_pod_configs
  pod 'Shimmer', :configurations => demoapp_pod_configs
  # SwiftProtobuf is needed by MSPCore at compile time
  pod 'SwiftProtobuf', '~> 1.28.2', :configurations => demoapp_pod_configs
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      
      # Disable Swift module interface verification for Pods targets
      # MSPCore uses @_implementationOnly import for MSPPrebidAdapter, so no swiftinterface needed
      config.build_settings['SWIFT_EMIT_MODULE_INTERFACE'] = 'NO'
      config.build_settings['SWIFT_INSTALL_MODULE_FOR_DEPLOYMENT'] = 'NO'
      config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'NO'
      
      config.build_settings['OTHER_SWIFT_FLAGS'] ||= ''
      # Remove -import-underlying-module flag from ALL pods
      # This flag causes "cannot load underlying module" errors for pods without ObjC code
      config.build_settings['OTHER_SWIFT_FLAGS'] = config.build_settings['OTHER_SWIFT_FLAGS'].to_s.gsub(/-import-underlying-module/, '').strip
      # Remove any existing -no-verify-emitted-module-interface if present, then add it
      config.build_settings['OTHER_SWIFT_FLAGS'] = config.build_settings['OTHER_SWIFT_FLAGS'].to_s.gsub(/\s*-no-verify-emitted-module-interface\s*/, '').strip
      config.build_settings['OTHER_SWIFT_FLAGS'] << ' -no-verify-emitted-module-interface' unless config.build_settings['OTHER_SWIFT_FLAGS'].include?('-no-verify-emitted-module-interface')

      # Note: Kingfisher-specific patching removed - now using MSPKingfisher wrapper
      # which has BUILD_LIBRARY_FOR_DISTRIBUTION=NO set in its podspec
      
      # --- Enable Swift module generation for Shimmer ---
      # Fix "no such module 'Shimmer'" during XCFramework archive
      # Enable Swift import for Shimmer (Obj-C pod) by generating Shimmer.swiftmodule
      if target.name == "Shimmer"
        puts "[post_install] Enabling Swift module generation for Shimmer"
        config.build_settings["DEFINES_MODULE"] = "YES"
        config.build_settings["CLANG_ENABLE_MODULES"] = "YES"
        config.build_settings["SWIFT_OBJC_BRIDGING_HEADER"] = ""
      end
    end
    
    # Remove SwiftVerifyEmittedModuleInterface build phases from Pods targets
    target.build_phases.each do |phase|
      if phase.respond_to?(:name) && phase.name == 'SwiftVerifyEmittedModuleInterface'
        target.build_phases.delete(phase)
      elsif phase.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
        if phase.shell_script && phase.shell_script.include?('SwiftVerifyEmittedModuleInterface')
          target.build_phases.delete(phase)
        end
      end
    end
    
    # --- Patch [CP] Copy XCFrameworks script to support MSP_SKIP_CP_XCFRAMEWORKS guard ---
    # This allows Core XCFramework builds to skip the copy script when XCFrameworks don't exist yet
    # The script will still run normally for MSPDemoApp builds when XCFrameworks are present
    target.build_phases.each do |phase|
      if phase.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
        if phase.name == '[CP] Copy XCFrameworks' || (phase.shell_script && phase.shell_script.include?('[CP] Copy XCFrameworks'))
          # Check if guard is already present (idempotent)
          unless phase.shell_script && phase.shell_script.include?('MSP_SKIP_CP_XCFRAMEWORKS')
            guard_script = <<~SCRIPT
              # MSP Guard: Skip [CP] Copy XCFrameworks during Core XCFramework builds
              # This prevents rsync errors when XCFrameworks don't exist yet
              if [ "$MSP_SKIP_CP_XCFRAMEWORKS" = "1" ]; then
                echo "[MSP] Skipping [CP] Copy XCFrameworks because MSP_SKIP_CP_XCFRAMEWORKS=1"
                exit 0
              fi
              
            SCRIPT
            phase.shell_script = guard_script + (phase.shell_script || '')
            puts "[post_install] Added MSP_SKIP_CP_XCFRAMEWORKS guard to [CP] Copy XCFrameworks for #{target.name}"
          end
        end
      end
    end
  end
  
  # Create module.modulemap symlink for Shimmer to make it discoverable by Swift
  # Swift requires modulemap to be named 'module.modulemap' in the include directory
  shimmer_modulemap_dir = File.join(installer.sandbox.root, "Headers/Public/Shimmer")
  shimmer_modulemap = File.join(shimmer_modulemap_dir, "Shimmer.modulemap")
  module_modulemap = File.join(shimmer_modulemap_dir, "module.modulemap")
  if File.exist?(shimmer_modulemap) && !File.exist?(module_modulemap)
    puts "[post_install] Creating module.modulemap symlink for Shimmer"
    File.symlink("Shimmer.modulemap", module_modulemap)
  end
  
  # Note: Swift module resolution for vendored XCFrameworks is handled via:
  # 1. FRAMEWORK_SEARCH_PATHS (already set in podspecs and xcconfig)
  # 2. Swift compiler automatically finds module.modulemap in framework/Modules/
  # 3. No need to add -I flags - they cause path mismatch errors
  
  # --- Fix adapter modulemaps to use relative paths for Swift Compatibility Header ---
  # This fixes "cannot load underlying module" errors when importing adapters
  adapter_pods = ["MSPPrebidAdapter", "MSPGoogleAdapter", "MSPFacebookAdapter", "NovaAdapter",
                  "AmazonAdapter", "UnityAdapter", "InmobiAdapter", "MobilefuseAdapter",
                  "MintegralAdapter", "PubmaticAdapter"]
  adapter_pods.each do |pod_name|
    target_support_files = File.join(installer.sandbox.root, "Target Support Files", pod_name)
    if Dir.exist?(target_support_files)
      puts "[post_install] Processing #{pod_name} support files"
      # Note: Modulemap fixing will be done at build time via xcconfig
    end
  end
  
  # --- Configure pure Swift adapters to not generate ObjC module ---
  # Remove umbrella header references to prevent "cannot load underlying module" errors
  installer.pods_project.targets.each do |target|
    if adapter_pods.include?(target.name)
      puts "[post_install] Configuring pure Swift module for #{target.name}"
      target.build_configurations.each do |config|
        # Disable generating ObjC module for pure Swift pods
        config.build_settings['DEFINES_MODULE'] = 'YES'
        config.build_settings['SWIFT_OBJC_INTERFACE_HEADER_NAME'] = ''
        config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
      end
    end
  end
  
  # --- Patch ALL xcconfig files to remove -import-underlying-module ---
  # This flag causes "cannot load underlying module" errors for pure Swift pods
  # CocoaPods generates this in xcconfig files which we need to patch directly
  puts "[post_install] Patching xcconfig files to remove -import-underlying-module..."
  Dir.glob(File.join(installer.sandbox.root, "Target Support Files", "*", "*.xcconfig")).each do |xcconfig_path|
    content = File.read(xcconfig_path)
    if content.include?("-import-underlying-module")
      new_content = content.gsub(/-import-underlying-module/, '')
      File.write(xcconfig_path, new_content)
      puts "[post_install] Patched: #{File.basename(xcconfig_path)}"
    end
  end
  puts "[post_install] xcconfig patching complete"
end
