#!/bin/bash
set -e

PREFIX="${PREFIX:-$HOME/.local}"
OPTIMIZE="${OPTIMIZE:-ReleaseSafe}"

echo "Installing dbc to $PREFIX/bin..."
zig build -Doptimize=$OPTIMIZE --prefix "$PREFIX"

echo ""
echo "✓ dbc installed successfully!"
echo ""
echo "Make sure $PREFIX/bin is in your PATH"
echo "If not, add the following to your shell config:"
echo "  export PATH=\"$PREFIX/bin:\$PATH\""