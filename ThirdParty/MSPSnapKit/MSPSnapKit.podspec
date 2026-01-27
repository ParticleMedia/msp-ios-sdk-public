Pod::Spec.new do |s|
  s.name         = "MSPSnapKit"
  s.version      = "5.6.0-local"
  s.summary      = "MSP private SnapKit module to avoid symbol collisions."
  s.description  = "Wraps SnapKit with module name MSPSnapKit so MSP can link it without conflicting with host SnapKit."

  s.homepage     = "https://github.com/SnapKit/SnapKit"
  s.license      = { :type => "MIT" }
  s.author       = { "SnapKit" => "https://github.com/SnapKit" }

  # Keep upstream source reference (used for metadata); local path uses prepare_command
  s.source       = { :git => "https://github.com/SnapKit/SnapKit.git", :tag => "5.6.0" }

  s.swift_version = "5.0"
  s.platform     = :ios, "15.0"

  # Private module name to avoid collisions with host SnapKit
  s.module_name = "MSPSnapKit"
  s.static_framework = true

  # Download and prepare source files (mirrors MSPKingfisher pattern)
  s.prepare_command = <<-CMD
    if [ ! -d "Sources" ]; then
      echo "Downloading SnapKit source..."
      git clone --depth 1 --branch 5.6.0 https://github.com/SnapKit/SnapKit.git temp_snapkit
      cp -R temp_snapkit/Sources .
      rm -rf temp_snapkit
    fi
  CMD

  s.source_files = "Sources/**/*.{swift}"

  # Disable .swiftinterface generation (consistent with other internal wrappers)
  s.pod_target_xcconfig = {
    "BUILD_LIBRARY_FOR_DISTRIBUTION" => "NO",
    "SWIFT_EMIT_MODULE_INTERFACE" => "NO",
    "SWIFT_INSTALL_MODULE_FOR_DEPLOYMENT" => "NO"
  }

  s.user_target_xcconfig = {
    "BUILD_LIBRARY_FOR_DISTRIBUTION" => "NO",
    "SWIFT_EMIT_MODULE_INTERFACE" => "NO",
    "SWIFT_INSTALL_MODULE_FOR_DEPLOYMENT" => "NO"
  }
end
