#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
INSTALL_DIR="$SCRIPT_DIR/lib"
LIBTORRENT_VERSION="v2.0.10"

echo "==> Checking dependencies..."
command -v cmake >/dev/null 2>&1 || { echo "cmake required. Install with: brew install cmake"; exit 1; }
command -v brew >/dev/null 2>&1 || { echo "Homebrew required."; exit 1; }

# Ensure boost and openssl are available
BOOST_ROOT="$(brew --prefix boost)"
OPENSSL_ROOT="$(brew --prefix openssl@3)"

if [ ! -d "$BOOST_ROOT" ]; then
    echo "==> Installing boost..."
    brew install boost
    BOOST_ROOT="$(brew --prefix boost)"
fi

if [ ! -d "$OPENSSL_ROOT" ]; then
    echo "==> Installing openssl@3..."
    brew install openssl@3
    OPENSSL_ROOT="$(brew --prefix openssl@3)"
fi

echo "==> Cloning libtorrent $LIBTORRENT_VERSION..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

git clone --recurse-submodules --depth 1 --branch "$LIBTORRENT_VERSION" \
    https://github.com/arvidn/libtorrent.git

cd libtorrent
mkdir build && cd build

echo "==> Configuring with CMake..."
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_CXX_STANDARD=17 \
    -DBUILD_SHARED_LIBS=OFF \
    -Dencryption=ON \
    -DOPENSSL_ROOT_DIR="$OPENSSL_ROOT" \
    -DBoost_ROOT="$BOOST_ROOT" \
    -Dpython-bindings=OFF \
    -Dpython-egg-info=OFF

echo "==> Building..."
cmake --build . --config Release -j "$(sysctl -n hw.ncpu)"

echo "==> Installing to $INSTALL_DIR..."
cmake --install .

echo "==> Done! libtorrent installed to $INSTALL_DIR"
echo "    Headers: $INSTALL_DIR/include/"
echo "    Library: $INSTALL_DIR/lib/"
