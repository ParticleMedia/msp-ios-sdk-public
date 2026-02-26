#!/usr/bin/env bash
# Fix artifact paths after downloading from GitHub Actions
# GitHub Actions may extract XCFrameworks, so we need to reconstruct them

set -euo pipefail

# Use canonical path per README: Build/ReleaseArtifacts/XCFrameworks/
XCFRAMEWORKS_DIR="Build/ReleaseArtifacts/XCFrameworks"

mkdir -p "$XCFRAMEWORKS_DIR"

echo "🔍 Checking for XCFrameworks in $XCFRAMEWORKS_DIR..."
echo "Current working directory: $(pwd)"
echo "Full path to XCFrameworks dir: $(cd "$XCFRAMEWORKS_DIR" && pwd)"

echo ""
echo "📂 Directory structure before fixing:"
find "$XCFRAMEWORKS_DIR" -type d -maxdepth 3 2>/dev/null | head -20 || echo "  (empty or error)"

xcframeworks_found=()
while IFS= read -r -d '' xcf; do
  xcframeworks_found+=("$xcf")
done < <(find "$XCFRAMEWORKS_DIR" -name "*.xcframework" -type d -print0 2>/dev/null || true)

# If no .xcframework directories found, check if XCFramework was extracted
if [ ${#xcframeworks_found[@]} -eq 0 ]; then
  echo ""
  echo "⚠️  No .xcframework directories found. Checking if XCFramework was extracted..."
  
  # Look for platform directories (ios-arm64, ios-arm64_x86_64-simulator, etc.)
  # These indicate an extracted XCFramework
  platform_dirs=()
  while IFS= read -r -d '' dir; do
    platform_dirs+=("$dir")
  done < <(find "$XCFRAMEWORKS_DIR" -maxdepth 1 -type d -name "ios-*" -print0 2>/dev/null || true)
  
  if [ ${#platform_dirs[@]} -gt 0 ]; then
    echo "Found ${#platform_dirs[@]} platform directory(ies), reconstructing XCFramework(s)..."
    
    # Collect unique framework names from ALL platform directories (compatible with bash 3.x)
    # Important: Each platform directory may contain multiple frameworks!
    framework_names=()
    # Collect ALL framework names from ALL platform directories
    for platform_dir in "${platform_dirs[@]}"; do
      # Find ALL frameworks in this platform directory, not just the first one
      while IFS= read -r framework_path; do
        if [ -n "$framework_path" ]; then
          framework_name=$(basename "$framework_path" .framework)
          # Check if framework_name is already in the array
          found=false
          for existing_name in "${framework_names[@]}"; do
            if [ "$existing_name" = "$framework_name" ]; then
              found=true
              break
            fi
          done
          if [ "$found" = false ]; then
            framework_names+=("$framework_name")
            echo "  Found framework: $framework_name"
          fi
        fi
      done < <(find "$platform_dir" -name "*.framework" -type d -maxdepth 1 2>/dev/null || true)
    done
    
    if [ ${#framework_names[@]} -eq 0 ]; then
      echo "❌ Could not determine framework name(s) from extracted structure"
      echo "Contents of $XCFRAMEWORKS_DIR:"
      ls -la "$XCFRAMEWORKS_DIR" 2>/dev/null || echo "Directory does not exist"
      exit 1
    fi
    
    echo "Detected ${#framework_names[@]} framework(s): ${framework_names[*]}"
    
    # Reconstruct each XCFramework
    # First, we need to handle the case where multiple frameworks are in the same platform directory
    # We'll create separate platform directories for each framework
    
    for framework_name in "${framework_names[@]}"; do
      xcframework_path="$XCFRAMEWORKS_DIR/$framework_name.xcframework"
      echo ""
      echo "Reconstructing $xcframework_path..."
      
      # Remove existing if present
      rm -rf "$xcframework_path"
      mkdir -p "$xcframework_path"
      
      # Process each platform directory
      moved_count=0
      for platform_dir in "${platform_dirs[@]}"; do
        # Check if this platform directory still exists (might have been processed already)
        if [ ! -d "$platform_dir" ]; then
          continue
        fi
        
        platform_name=$(basename "$platform_dir")
        
        # Check if this platform directory contains the framework we're looking for
        framework_path=$(find "$platform_dir" -name "$framework_name.framework" -type d -maxdepth 1 2>/dev/null | head -1)
        
        if [ -n "$framework_path" ]; then
          # Check if this platform directory contains ONLY this framework (simple case)
          other_frameworks=$(find "$platform_dir" -name "*.framework" -type d -maxdepth 1 ! -name "$framework_name.framework" 2>/dev/null | wc -l | tr -d ' ')
          
          if [ "$other_frameworks" = "0" ]; then
            # Simple case: platform directory contains only this framework
            echo "  Moving $platform_name (contains only $framework_name.framework) to XCFramework..."
            mv "$platform_dir" "$xcframework_path/"
            ((moved_count++)) || true
          else
            # Complex case: platform directory contains multiple frameworks
            # Create a new platform directory for this framework
            new_platform_dir="$xcframework_path/$platform_name"
            echo "  Creating $platform_name for $framework_name (shared platform directory)..."
            mkdir -p "$new_platform_dir"
            
            # Copy the framework to the new platform directory
            cp -R "$framework_path" "$new_platform_dir/"
            
            # Copy Info.plist if it exists in the original platform directory
            if [ -f "$platform_dir/Info.plist" ]; then
              cp "$platform_dir/Info.plist" "$new_platform_dir/"
            fi
            
            ((moved_count++)) || true
          fi
        fi
      done
      
      if [ "$moved_count" -eq 0 ]; then
        echo "  ⚠️  No platform directories found for $framework_name, removing empty XCFramework..."
        rm -rf "$xcframework_path"
        continue
      fi
      
      # Handle Info.plist - try to find the right one for this framework
      # When multiple frameworks exist, we need to check which Info.plist belongs to which
      info_plist_found=false
      if [ -f "$XCFRAMEWORKS_DIR/Info.plist" ]; then
        # If only one framework, use the Info.plist
        if [ ${#framework_names[@]} -eq 1 ]; then
          echo "  Moving Info.plist to XCFramework..."
          mv "$XCFRAMEWORKS_DIR/Info.plist" "$xcframework_path/"
          info_plist_found=true
        else
          # For multiple frameworks, check if Info.plist references this framework
          if grep -q "$framework_name" "$XCFRAMEWORKS_DIR/Info.plist" 2>/dev/null; then
            echo "  Moving Info.plist (references $framework_name) to XCFramework..."
            mv "$XCFRAMEWORKS_DIR/Info.plist" "$xcframework_path/"
            info_plist_found=true
          fi
        fi
      fi
      
      # Check if Info.plist exists inside the XCFramework (might have been in platform dir)
      if [ "$info_plist_found" = false ]; then
        for platform_subdir in "$xcframework_path"/*; do
          if [ -d "$platform_subdir" ] && [ -f "$platform_subdir/Info.plist" ]; then
            # Copy Info.plist from platform directory if not found at root
            if [ ! -f "$xcframework_path/Info.plist" ]; then
              echo "  Copying Info.plist from platform directory..."
              cp "$platform_subdir/Info.plist" "$xcframework_path/"
            fi
            break
          fi
        done
      fi
      
      xcframeworks_found+=("$xcframework_path")
      echo "✅ Reconstructed $framework_name.xcframework ($moved_count platform(s))"
    done
  else
    # Check if there are subdirectories that might contain XCFrameworks
    echo "Checking subdirectories for XCFrameworks..."
    for subdir in "$XCFRAMEWORKS_DIR"/*; do
      if [ -d "$subdir" ]; then
        subdir_name=$(basename "$subdir")
        # Skip if it's already a platform directory pattern
        if [[ ! "$subdir_name" =~ ^ios- ]]; then
          xcf_in_subdir=$(find "$subdir" -name "*.xcframework" -type d 2>/dev/null | head -1)
          if [ -n "$xcf_in_subdir" ]; then
            xcf_name=$(basename "$xcf_in_subdir")
            echo "Found $xcf_name in subdirectory, moving to $XCFRAMEWORKS_DIR..."
            mv "$xcf_in_subdir" "$XCFRAMEWORKS_DIR/"
            xcframeworks_found+=("$XCFRAMEWORKS_DIR/$xcf_name")
          fi
        fi
      fi
    done
  fi
fi

# Move XCFrameworks to correct location if they're in subdirectories
echo ""
echo "🔧 Ensuring XCFrameworks are in correct location..."
for xcf in "${xcframeworks_found[@]}"; do
  xcf_name=$(basename "$xcf")
  xcf_parent=$(dirname "$xcf")
  xcf_parent_abs=$(cd "$xcf_parent" && pwd)
  xcframeworks_dir_abs=$(cd "$XCFRAMEWORKS_DIR" && pwd)
  
  # If XCFramework is not directly in canonical directory, move it
  if [ "$xcf_parent_abs" != "$xcframeworks_dir_abs" ]; then
    if [ ! -d "$XCFRAMEWORKS_DIR/$xcf_name" ]; then
      echo "📦 Moving $xcf to $XCFRAMEWORKS_DIR/"
      mv "$xcf" "$XCFRAMEWORKS_DIR/"
      echo "  ✅ Moved successfully"
    else
      echo "⚠️  $xcf_name already exists in $XCFRAMEWORKS_DIR, removing duplicate at $xcf"
      rm -rf "$xcf"
    fi
  else
    echo "✅ $xcf_name is already in correct location"
  fi
done

echo ""
echo "📋 Final XCFrameworks in $XCFRAMEWORKS_DIR:"
found_final=false
found_xcframeworks=()
if ls -1 "$XCFRAMEWORKS_DIR"/*.xcframework 2>/dev/null; then
  for xcf in "$XCFRAMEWORKS_DIR"/*.xcframework; do
    if [ -d "$xcf" ]; then
      xcf_name=$(basename "$xcf")
      echo "  ✅ $xcf_name"
      found_xcframeworks+=("$xcf_name")
      found_final=true
    fi
  done
fi

if [ "$found_final" = false ]; then
  echo "  ❌ No XCFrameworks found!"
  echo "Contents:"
  ls -la "$XCFRAMEWORKS_DIR" 2>/dev/null || echo "  (directory does not exist)"
  echo ""
  echo "Attempting fallback: checking for extracted platform directories..."
  
  # Fallback: try to reconstruct from any remaining platform directories
  remaining_platforms=()
  while IFS= read -r -d '' dir; do
    remaining_platforms+=("$dir")
  done < <(find "$XCFRAMEWORKS_DIR" -maxdepth 1 -type d -name "ios-*" -print0 2>/dev/null || true)
  
  if [ ${#remaining_platforms[@]} -gt 0 ]; then
    echo "Found ${#remaining_platforms[@]} remaining platform directory(ies), attempting reconstruction..."
    # Re-run the reconstruction logic
    exit 1
  else
    exit 1
  fi
fi

# Validate XCFramework structure
echo ""
echo "🔍 Validating XCFramework structures..."
validation_failed=false
for xcf_name in "${found_xcframeworks[@]}"; do
  xcf_path="$XCFRAMEWORKS_DIR/$xcf_name"
  
  # Check if it has at least one platform directory
  platform_count=$(find "$xcf_path" -maxdepth 1 -type d -name "ios-*" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$platform_count" -eq 0 ]; then
    echo "  ❌ $xcf_name: No platform directories found"
    validation_failed=true
  else
    # Check if Info.plist exists
    if [ ! -f "$xcf_path/Info.plist" ]; then
      echo "  ⚠️  $xcf_name: Info.plist not found (may be in platform directory)"
    fi
    echo "  ✅ $xcf_name: Valid ($platform_count platform(s))"
  fi
done

if [ "$validation_failed" = true ]; then
  echo ""
  echo "❌ Some XCFrameworks have invalid structure"
  exit 1
fi
