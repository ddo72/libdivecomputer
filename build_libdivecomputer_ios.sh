#!/bin/bash
set -e

LIB_NAME="libdivecomputer"
SRC_DIR="src"
INC_DIR="include"
BUILD_DIR="build-ios"
OUT_DIR="output"

rm -rf "$BUILD_DIR" "$OUT_DIR"
mkdir -p "$BUILD_DIR/device" "$BUILD_DIR/simulator-arm64" "$BUILD_DIR/simulator-x86_64" "$OUT_DIR"

# ----------------------------
# Source files allowed for iOS
# ----------------------------
IOS_SOURCES=$(ls $SRC_DIR/*.c | grep -v -e serial_ -e usb -e usbhid -e socket -e irda)

echo "Using iOS-safe source list:"
echo "$IOS_SOURCES"
echo ""

build_target() {
    ARCH=$1
    SDK=$2
    TARGET=$3
    OUTPUT=$4

    echo "Building $ARCH for $SDK"
    mkdir -p "$OUTPUT"

    for SRC in $IOS_SOURCES; do
        OBJ="${OUTPUT}/$(basename ${SRC%.c}).o"
        echo "  Compiling $(basename $SRC) -> $(basename $OBJ)"
        clang -arch "$ARCH" \
            -isysroot "$(xcrun --sdk $SDK --show-sdk-path)" \
            -target "$TARGET" \
            -I"$INC_DIR" \
            -D__APPLE__ \
            -c "$SRC" \
            -o "$OBJ"
    done

    # Create static lib
    libtool -static -o "${OUTPUT}/${LIB_NAME}.a" "${OUTPUT}"/*.o
}

# ----------------------------
# iOS Device (arm64)
# ----------------------------
build_target \
    "arm64" \
    "iphoneos" \
    "arm64-apple-ios10.0" \
    "${BUILD_DIR}/device"

# ----------------------------
# iOS Simulator (arm64 + x86_64)
# ----------------------------
build_target \
    "arm64" \
    "iphonesimulator" \
    "arm64-apple-ios10.0-simulator" \
    "${BUILD_DIR}/simulator-arm64"

build_target \
    "x86_64" \
    "iphonesimulator" \
    "x86_64-apple-ios10.0-simulator" \
    "${BUILD_DIR}/simulator-x86_64"

mkdir -p "${BUILD_DIR}/simulator-universal"
lipo -create \
    "${BUILD_DIR}/simulator-arm64/${LIB_NAME}.a" \
    "${BUILD_DIR}/simulator-x86_64/${LIB_NAME}.a" \
    -output "${BUILD_DIR}/simulator-universal/${LIB_NAME}.a"

# ----------------------------
# Create XCFramework
# ----------------------------
xcodebuild -create-xcframework \
  -library "${BUILD_DIR}/device/${LIB_NAME}.a" \
  -headers "$INC_DIR" \
  -library "${BUILD_DIR}/simulator-universal/${LIB_NAME}.a" \
  -headers "$INC_DIR" \
  -output "${OUT_DIR}/${LIB_NAME}.xcframework"

echo ""
echo "========================================"
echo "Build complete!"
echo " → ${OUT_DIR}/${LIB_NAME}.xcframework"
echo "========================================"
