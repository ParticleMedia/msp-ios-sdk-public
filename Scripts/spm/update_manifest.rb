#!/usr/bin/env ruby
# ============================================================================
# update_manifest.rb
# ============================================================================
# Updates Package.swift binary targets from path: to url: + checksum:
#
# Usage:
#   ruby Scripts/spm/update_manifest.rb <Package.swift> <TargetName> <RemoteURL> <Checksum>
#
# Example:
#   ruby Scripts/spm/update_manifest.rb Package.swift FBAudienceNetwork \
#     "https://github.com/ParticleMedia/msp-ios-sdk-public/releases/download/0.3.0-rc.5/FBAudienceNetwork.xcframework.zip" \
#     "abc123def456..."
# ============================================================================

if ARGV.length != 4
  STDERR.puts "Usage: #{$0} <Package.swift> <TargetName> <RemoteURL> <Checksum>"
  exit 1
end

package_swift_path = ARGV[0]
target_name = ARGV[1]
remote_url = ARGV[2]
checksum = ARGV[3]

# Read Package.swift
unless File.exist?(package_swift_path)
  STDERR.puts "Error: Package.swift not found: #{package_swift_path}"
  exit 1
end

# Read Package.swift with UTF-8 encoding
package_content = File.read(package_swift_path, encoding: 'UTF-8')

# Pattern to match: .binaryTarget(name: "TargetName", path: "...")
# We need to match the entire binaryTarget block with proper indentation
# The pattern should match both single-line and multi-line formats:
#   .binaryTarget(name: "TargetName", path: "...")
#   .binaryTarget(
#       name: "TargetName",
#       path: "path/to/TargetName.xcframework"
#   )
# Use a more flexible pattern that handles both cases
pattern = /\.binaryTarget\(\s*name:\s*"#{Regexp.escape(target_name)}",\s*path:\s*"[^"]+"\s*\)/m

# Replacement with url and checksum
# Maintain the same indentation style
replacement = %Q(.binaryTarget(
            name: "#{target_name}",
            url: "#{remote_url}",
            checksum: "#{checksum}"
        ))

# Perform replacement
new_content = package_content.gsub(pattern, replacement)

# Check if replacement was made
if new_content == package_content
  STDERR.puts "Warning: No replacement made for target: #{target_name}"
  STDERR.puts "Pattern may not match. Current binaryTarget definition:"
  # Try to find the target definition
  if package_content =~ /\.binaryTarget\([^)]*name:\s*"#{Regexp.escape(target_name)}"[^)]*\)/m
    STDERR.puts $&
  end
  exit 1
end

# Write updated content with UTF-8 encoding
File.write(package_swift_path, new_content, encoding: 'UTF-8')

puts "Successfully updated #{target_name} in #{package_swift_path}"
puts "  URL: #{remote_url}"
puts "  Checksum: #{checksum[0..15]}..."

exit 0
