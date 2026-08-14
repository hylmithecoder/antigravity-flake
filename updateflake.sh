#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# Color codes for pretty output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Send all status/information logs to stderr to avoid polluting stdout capturing!
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Resolve paths relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_NIX="$SCRIPT_DIR/flake.nix"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"

# Verify required files exist
if [ ! -f "$FLAKE_NIX" ] || [ ! -f "$PACKAGE_NIX" ]; then
    log_error "Could not find flake.nix or package.nix in $SCRIPT_DIR"
    exit 1
fi

# Get URL from argument or prompt the user
URL=""
if [ $# -ge 1 ]; then
    URL="$1"
else
    echo -e "${YELLOW}Please enter the Google Antigravity download URL:${NC}" >&2
    read -r URL
fi

if [ -z "$URL" ]; then
    log_error "No URL provided."
    exit 1
fi

log_info "Processing URL: $URL"

# Extract version from URL
# e.g., https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.0.3-6242596486512640/linux-x64/Antigravity%20IDE.tar.gz
# Should extract: 2.0.3-6242596486512640
version=$(echo "$URL" | sed -n 's|.*/stable/\([^/]*\)/.*|\1|p')

if [ -z "$version" ]; then
    log_error "Could not extract version from URL."
    log_warning "Expected format: .../stable/VERSION/linux-x64/..."
    log_info "Trying to parse any version-like folder name before 'linux-x64'..."
    version=$(echo "$URL" | sed -n 's|.*/\([^/]*\)/linux-x64/.*|\1|p')
fi

if [ -z "$version" ]; then
    log_error "Could not extract version from URL. Please ensure the URL is valid."
    exit 1
fi

log_info "Extracted version: $version"

# Function to convert a raw hash to SRI format
convert_to_sri() {
    local hash_val="$1"
    # Try nix hash convert (modern Nix)
    if nix --extra-experimental-features "nix-command" hash convert --help &>/dev/null; then
        nix --extra-experimental-features "nix-command" hash convert --to sri --type sha256 "$hash_val"
    else
        nix hash to-sri --type sha256 "$hash_val"
    fi
}

# Function to get the SRI hash
get_sri_hash() {
    local target_url="$1"
    
    # Method 1: Using nix store prefetch-file (modern Nix)
    if command -v nix &>/dev/null && command -v jq &>/dev/null; then
        log_info "Attempting to prefetch using 'nix store prefetch-file'..."
        log_info "Running: nix --extra-experimental-features \"nix-command flakes\" store prefetch-file --json \"$target_url\""
        
        local json_output
        local err_file
        err_file=$(mktemp)
        if json_output=$(nix --extra-experimental-features "nix-command flakes" store prefetch-file --json "$target_url" 2>"$err_file"); then
            rm -f "$err_file"
            echo "$json_output" | jq -r '.hash'
            return 0
        else
            log_warning "'nix store prefetch-file' failed. Details:"
            cat "$err_file" | sed 's/^/  /' >&2
            rm -f "$err_file"
        fi
    fi
    
    # Method 2: Using nix-prefetch-url + nix hash convert (classic Nix fallback)
    if command -v nix-prefetch-url &>/dev/null; then
        log_info "Attempting to prefetch using 'nix-prefetch-url'..."
        log_info "Running: nix-prefetch-url --type sha256 \"$target_url\""
        
        local raw_hash
        local err_file
        err_file=$(mktemp)
        if raw_hash=$(nix-prefetch-url --type sha256 "$target_url" 2>"$err_file"); then
            rm -f "$err_file"
            if [ -n "$raw_hash" ]; then
                log_info "Raw sha256 (base32) obtained: $raw_hash"
                log_info "Converting hash to SRI format..."
                
                local sri_val
                if sri_val=$(convert_to_sri "$raw_hash" 2>&1); then
                    echo "$sri_val"
                    return 0
                else
                    log_warning "Failed to convert hash using nix hash convert: $sri_val"
                fi
            fi
        else
            log_warning "'nix-prefetch-url' failed. Details:"
            cat "$err_file" | sed 's/^/  /' >&2
            rm -f "$err_file"
        fi
    fi
    
    # Method 3: Using curl + openssl (non-Nix fallback)
    if command -v curl &>/dev/null; then
        log_warning "Nix tools failed or are not available. Falling back to curl + openssl..."
        log_info "Running: curl -sSL \"$target_url\" | openssl dgst -sha256 -binary | openssl enc -base64"
        
        local base64_sri
        local err_file
        err_file=$(mktemp)
        if base64_sri=$(curl -sSL "$target_url" 2>"$err_file" | openssl dgst -sha256 -binary 2>>"$err_file" | openssl enc -base64 2>>"$err_file"); then
            rm -f "$err_file"
            # Strip any trailing whitespace/newlines from base64 output
            base64_sri=$(echo "$base64_sri" | tr -d ' \t\r\n')
            echo "sha256-$base64_sri"
            return 0
        else
            log_warning "curl + openssl failed. Details:"
            cat "$err_file" | sed 's/^/  /' >&2
            rm -f "$err_file"
        fi
    fi

    log_error "Could not fetch or compute hash through any available method."
    return 1
}

# Fetch the SRI hash
sri_hash=$(get_sri_hash "$URL")
if [ -z "$sri_hash" ]; then
    log_error "Failed to retrieve the file hash."
    exit 1
fi

log_info "Computed SRI hash: $sri_hash"

# Construct URL template (replacing the version string with ${version} literal for package.nix)
template_url=$(echo "$URL" | sed 's|'"$version"'|${version}|g')
log_info "Constructed URL template: $template_url"

# Update flake.nix
log_info "Updating $FLAKE_NIX..."
sed -i "s/version = \"[^\"]*\";/version = \"$version\";/g" "$FLAKE_NIX"

# Update devShell short version message in flake.nix
short_version=$(echo "$version" | cut -d'-' -f1)
sed -i "s/Google Antigravity [0-9.]* Flake Environment/Google Antigravity $short_version Flake Environment/g" "$FLAKE_NIX"

# Update package.nix
log_info "Updating $PACKAGE_NIX..."
sed -i "s/version = \"[^\"]*\";/version = \"$version\";/g" "$PACKAGE_NIX"
sed -i "s|url = \"[^\"]*\";|url = \"$template_url\";|g" "$PACKAGE_NIX"
sed -i "s|sha256 = \"[^\"]*\";|sha256 = \"$sri_hash\";|g" "$PACKAGE_NIX"

log_success "Flake version and hash updated successfully to $version!"
log_success "You can now run your flake build/run or add it to your Home Manager configuration."
