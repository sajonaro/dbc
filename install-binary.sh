#!/bin/bash
set -e

PREFIX="${PREFIX:-$HOME/.local}"
VERSION="${VERSION:-latest}"
REPO="sajonaro/dbc"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_error() {
    echo -e "${RED}✗ Error: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ Warning: $1${NC}"
}

print_info() {
    echo -e "$1"
}

# Check for required commands
check_prerequisites() {
    local missing_tools=()
    
    # Check for curl
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    # Check for tar
    if ! command -v tar &> /dev/null; then
        missing_tools+=("tar")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo ""
        print_error "Missing required tools"
        echo ""
        print_info "Missing:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo ""
        print_info "Please install these tools and try again."
        echo ""
        
        # Provide OS-specific installation hints
        if [ -f /etc/debian_version ]; then
            print_info "On Ubuntu/Debian, run:"
            echo "  sudo apt update && sudo apt install -y curl tar"
        elif [ -f /etc/redhat-release ]; then
            print_info "On RHEL/CentOS/Fedora, run:"
            echo "  sudo dnf install -y curl tar"
        elif [ -f /etc/arch-release ]; then
            print_info "On Arch Linux, run:"
            echo "  sudo pacman -S curl tar"
        elif [ "$(uname -s)" = "Darwin" ]; then
            print_info "On macOS, curl and tar should be pre-installed."
        fi
        
        echo ""
        exit 1
    fi
}

# Detect OS and architecture
detect_platform() {
    case "$(uname -s)" in
        Linux*)
            case "$(uname -m)" in
                x86_64) echo "linux-x86_64" ;;
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
        echo ""
        print_error "Platform $(uname -s) $(uname -m) is not supported for pre-built binaries"
        echo ""
        print_info "Supported platforms:"
        echo "  - Linux x86_64"
        echo ""
        print_info "You can build from source instead:"
        echo "  curl -sSL https://raw.githubusercontent.com/$REPO/master/install.sh | bash"
        echo ""
        exit 1
    fi
    
    print_info "Installing dbc for $platform..."
    echo ""
    
    local url
    if [ "$VERSION" = "latest" ]; then
        url="https://github.com/$REPO/releases/latest/download/dbc-$platform.tar.gz"
    else
        url="https://github.com/$REPO/releases/download/$VERSION/dbc-$platform.tar.gz"
    fi
    
    print_info "Downloading from: $url"
    
    # Create bin directory if it doesn't exist
    mkdir -p "$PREFIX/bin"
    
    # Download and extract
    if curl -sSL "$url" | tar xz -C "$PREFIX/bin"; then
        chmod +x "$PREFIX/bin/dbc"
        echo ""
        print_success "dbc installed successfully to $PREFIX/bin/dbc"
        echo ""
        print_info "Make sure $PREFIX/bin is in your PATH"
        print_info "If not, add the following to your shell config:"
        echo "  export PATH=\"$PREFIX/bin:\$PATH\""
        echo ""
        print_info "Run 'dbc' to start using it!"
        
        # Check for runtime dependencies
        echo ""
        print_info "Checking runtime dependencies..."
        local missing_libs=()
        
        if ! ldconfig -p 2>/dev/null | grep -q libncursesw; then
            missing_libs+=("libncursesw (ncurses)")
        fi
        
        if ! ldconfig -p 2>/dev/null | grep -q libpq; then
            missing_libs+=("libpq (PostgreSQL client library)")
        fi
        
        if [ ${#missing_libs[@]} -ne 0 ]; then
            echo ""
            print_warning "Some runtime libraries may be missing:"
            for lib in "${missing_libs[@]}"; do
                echo "  - $lib"
            done
            echo ""
            print_info "If dbc fails to run, install these libraries:"
            if [ -f /etc/debian_version ]; then
                echo "  sudo apt install -y libncursesw6 libpq5"
            elif [ -f /etc/redhat-release ]; then
                echo "  sudo dnf install -y ncurses-libs postgresql-libs"
            elif [ -f /etc/arch-release ]; then
                echo "  sudo pacman -S ncurses postgresql-libs"
            fi
        else
            print_success "All runtime dependencies found!"
        fi
    else
        echo ""
        print_error "Failed to download pre-built binary"
        echo ""
        print_info "Possible reasons:"
        echo "  - No release available for version: $VERSION"
        echo "  - Network connectivity issues"
        echo "  - GitHub API rate limit"
        echo ""
        print_info "You can try building from source instead:"
        echo "  curl -sSL https://raw.githubusercontent.com/$REPO/master/install.sh | bash"
        echo ""
        exit 1
    fi
}

# Main installation
main() {
    echo "========================================"
    echo "  dbc Installation (Pre-built Binary)"
    echo "========================================"
    echo ""
    
    print_info "Checking prerequisites..."
    check_prerequisites
    
    echo ""
    print_success "All prerequisites found!"
    echo ""
    
    install_prebuilt
}

main