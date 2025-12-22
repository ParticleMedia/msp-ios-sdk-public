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

# Pattern 1: Match .binaryTarget with path: (needs conversion to url: + checksum:)
pattern_path = /\.binaryTarget\(\s*name:\s*"#{Regexp.escape(target_name)}",\s*path:\s*"[^"]+"\s*\)/m

# Pattern 2: Match .binaryTarget with url: and checksum: (needs checksum update)
# This pattern matches multi-line format with url and checksum
pattern_url = /\.binaryTarget\(\s*name:\s*"#{Regexp.escape(target_name)}",\s*url:\s*"[^"]+",\s*checksum:\s*"[^"]+"\s*\)/m

# Replacement with url and checksum (same for both cases)
replacement = %Q(.binaryTarget(
            name: "#{target_name}",
            url: "#{remote_url}",
            checksum: "#{checksum}"
        ))

# Try pattern 1 first (path: → url: + checksum:)
new_content = package_content.gsub(pattern_path, replacement)

# If no replacement, try pattern 2 (update existing url: + checksum:)
if new_content == package_content
  new_content = package_content.gsub(pattern_url, replacement)
end

# Check if replacement was made
if new_content == package_content
  # Check if target exists as .target (source-based) instead of .binaryTarget
  if package_content =~ /\.target\([^)]*name:\s*"#{Regexp.escape(target_name)}"[^)]*\)/m
    STDERR.puts "Info: Target #{target_name} is a .target (source-based), not a .binaryTarget"
    STDERR.puts "Skipping binary target update (source-based targets don't need URL/checksum)"
    exit 0  # Success - this is expected for source-based targets
  end
  
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
