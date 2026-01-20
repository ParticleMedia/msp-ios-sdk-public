Pod::Spec.new do |s|
  s.name         = "MSPKingfisher"
  s.version      = "8.6.2-local"
  s.summary      = "MSP wrapper for Kingfisher to disable Swift interface verification."
  s.description  = "Wraps the real Kingfisher library so we can disable BUILD_LIBRARY_FOR_DISTRIBUTION and avoid SwiftVerifyEmittedModuleInterface errors."

  s.homepage     = "https://github.com/onevcat/Kingfisher"
  s.license      = { :type => "MIT" }
  s.author       = { "onevcat" => "onevcat@onevcat.com" }

  # Use the real Kingfisher source from the public repo
  s.source       = { :git => "https://github.com/onevcat/Kingfisher.git", :tag => "8.6.2" }

  s.swift_version = "5.0"
  s.platform     = :ios, "15.0"

  # Ensure module name is "Kingfisher" (not "MSPKingfisher") so source code can import it
  s.module_name = "Kingfisher"

  # Download and prepare source files
  s.prepare_command = <<-CMD
    if [ ! -d "Sources" ]; then
      echo "Downloading Kingfisher source..."
      git clone --depth 1 --branch 8.6.2 https://github.com/onevcat/Kingfisher.git temp_kingfisher
      cp -R temp_kingfisher/Sources .
      rm -rf temp_kingfisher
    fi
  CMD

  # Source files
  s.source_files = "Sources/**/*.{swift}"

  # Disable .swiftinterface generation
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

