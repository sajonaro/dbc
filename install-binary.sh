#!/bin/bash
set -e

PREFIX="${PREFIX:-$HOME/.local}"
VERSION="${VERSION:-latest}"
REPO="sajonaro/dbc"

# Detect OS and architecture
detect_platform() {
    case "$(uname -s)" in
        Linux*)
            case "$(uname -m)" in
                x86_64) echo "linux-x86_64" ;;
                *) echo "unsupported" ;;
            esac
            ;;
        Darwin*)
            case "$(uname -m)" in
                x86_64) echo "macos-x86_64" ;;
                arm64) echo "macos-aarch64" ;;
                *) echo "unsupported" ;;
            esac
            ;;
        *)
            echo "unsupported"
            ;;
    esac
}

# Download and install pre-built binary
install_prebuilt() {
    local platform=$(detect_platform)
    
    if [ "$platform" = "unsupported" ]; then
        echo "Error: Platform $(uname -s) $(uname -m) is not supported for pre-built binaries"
        echo ""
        echo "Supported platforms:"
        echo "  - Linux x86_64"
        echo "  - macOS x86_64 (Intel)"
        echo "  - macOS aarch64 (Apple Silicon)"
        echo ""
        echo "Please build from source using install.sh instead"
        exit 1
    fi
    
    echo "Installing dbc for $platform..."
    echo ""
    
    local url
    if [ "$VERSION" = "latest" ]; then
        url="https://github.com/$REPO/releases/latest/download/dbc-$platform.tar.gz"
    else
        url="https://github.com/$REPO/releases/download/$VERSION/dbc-$platform.tar.gz"
    fi
    
    echo "Downloading from: $url"
    
    # Create bin directory if it doesn't exist
    mkdir -p "$PREFIX/bin"
    
    # Download and extract
    if curl -sSL "$url" | tar xz -C "$PREFIX/bin"; then
        chmod +x "$PREFIX/bin/dbc"
        echo ""
        echo "✓ dbc installed successfully to $PREFIX/bin/dbc"
        echo ""
        echo "Make sure $PREFIX/bin is in your PATH"
        echo "If not, add the following to your shell config:"
        echo "  export PATH=\"$PREFIX/bin:\$PATH\""
        echo ""
        echo "Run 'dbc' to start using it!"
    else
        echo ""
        echo "✗ Failed to download pre-built binary"
        echo ""
        echo "Possible reasons:"
        echo "  - No release available for version: $VERSION"
        echo "  - Network connectivity issues"
        echo "  - GitHub API rate limit"
        echo ""
        echo "Please try building from source using install.sh instead"
        exit 1
    fi
}

install_prebuilt