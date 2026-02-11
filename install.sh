#!/bin/bash
set -e

PREFIX="${PREFIX:-$HOME/.local}"
OPTIMIZE="${OPTIMIZE:-ReleaseSafe}"

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

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)
            if [ -f /etc/debian_version ]; then
                echo "debian"
            elif [ -f /etc/redhat-release ]; then
                echo "redhat"
            elif [ -f /etc/arch-release ]; then
                echo "arch"
            else
                echo "linux"
            fi
            ;;
        Darwin*)
            echo "macos"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Check for required commands
check_prerequisites() {
    local missing_deps=()
    local missing_build_deps=()
    
    # Check for zig
    if ! command -v zig &> /dev/null; then
        missing_deps+=("zig")
    fi
    
    # Check for pkg-config (helps detect libraries)
    if ! command -v pkg-config &> /dev/null; then
        print_warning "pkg-config not found (optional but recommended)"
    fi
    
    # Detect OS
    local os=$(detect_os)
    
    # Check for ncurses development files
    if command -v pkg-config &> /dev/null; then
        if ! pkg-config --exists ncursesw 2>/dev/null; then
            missing_build_deps+=("ncursesw-dev")
        fi
        
        if ! pkg-config --exists libpq 2>/dev/null; then
            missing_build_deps+=("libpq-dev")
        fi
    else
        # Fallback: check for header files
        if [ ! -f /usr/include/ncursesw/ncurses.h ] && [ ! -f /usr/local/include/ncursesw/ncurses.h ]; then
            missing_build_deps+=("ncursesw-dev")
        fi
        
        if [ ! -f /usr/include/postgresql/libpq-fe.h ] && [ ! -f /usr/local/include/libpq-fe.h ]; then
            missing_build_deps+=("libpq-dev")
        fi
    fi
    
    # Report missing dependencies
    if [ ${#missing_deps[@]} -ne 0 ] || [ ${#missing_build_deps[@]} -ne 0 ]; then
        echo ""
        print_error "Missing required dependencies"
        echo ""
        
        if [ ${#missing_deps[@]} -ne 0 ]; then
            print_info "Missing tools:"
            for dep in "${missing_deps[@]}"; do
                echo "  - $dep"
            done
            echo ""
        fi
        
        if [ ${#missing_build_deps[@]} -ne 0 ]; then
            print_info "Missing build dependencies:"
            for dep in "${missing_build_deps[@]}"; do
                echo "  - $dep"
            done
            echo ""
        fi
        
        # Provide installation instructions based on OS
        print_info "Installation instructions:"
        echo ""
        
        case "$os" in
            debian)
                print_info "On Ubuntu/Debian, run:"
                if [ ${#missing_deps[@]} -ne 0 ]; then
                    echo "  # Install Zig from https://ziglang.org/download/"
                fi
                if [ ${#missing_build_deps[@]} -ne 0 ]; then
                    echo "  sudo apt update && sudo apt install -y libncursesw5-dev libpq-dev"
                fi
                ;;
            redhat)
                print_info "On RHEL/CentOS/Fedora, run:"
                if [ ${#missing_deps[@]} -ne 0 ]; then
                    echo "  # Install Zig from https://ziglang.org/download/"
                fi
                if [ ${#missing_build_deps[@]} -ne 0 ]; then
                    echo "  sudo dnf install -y ncurses-devel postgresql-devel"
                fi
                ;;
            arch)
                print_info "On Arch Linux, run:"
                if [ ${#missing_deps[@]} -ne 0 ]; then
                    echo "  sudo pacman -S zig"
                fi
                if [ ${#missing_build_deps[@]} -ne 0 ]; then
                    echo "  sudo pacman -S ncurses postgresql-libs"
                fi
                ;;
            macos)
                print_info "On macOS, run:"
                if [ ${#missing_deps[@]} -ne 0 ]; then
                    echo "  brew install zig"
                fi
                if [ ${#missing_build_deps[@]} -ne 0 ]; then
                    echo "  brew install ncurses postgresql"
                fi
                ;;
            *)
                print_info "Please install:"
                echo "  - Zig 0.15.2 or later: https://ziglang.org/download/"
                echo "  - ncurses development files"
                echo "  - PostgreSQL development files (libpq)"
                ;;
        esac
        
        echo ""
        exit 1
    fi
}

# Main installation
main() {
    echo "========================================"
    echo "  dbc Installation (Build from Source)"
    echo "========================================"
    echo ""
    
    print_info "Checking prerequisites..."
    check_prerequisites
    
    echo ""
    print_success "All prerequisites found!"
    echo ""
    
    print_info "Installing dbc to $PREFIX/bin..."
    zig build -Doptimize=$OPTIMIZE --prefix "$PREFIX"
    
    echo ""
    print_success "dbc installed successfully!"
    echo ""
    print_info "Make sure $PREFIX/bin is in your PATH"
    print_info "If not, add the following to your shell config:"
    echo "  export PATH=\"$PREFIX/bin:\$PATH\""
}

main