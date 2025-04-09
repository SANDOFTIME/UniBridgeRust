#!/bin/bash
set -e

PROJECT_NAME="uniffi_bridge"
OUTPUT_DIR="out"
DEST="$OUTPUT_DIR/$PROJECT_NAME.xcframework"
ENV="release"
STATIC_LIB_NAME="lib$PROJECT_NAME.a"
TARGET_DIR="target"

rm -rf "$OUTPUT_DIR"
rm -rf "$DEST"

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

rustup target add aarch64-apple-ios-sim
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-darwin

echo "Building aarch64-apple-ios"
cargo build --target aarch64-apple-ios --$ENV
echo "Building aarch64-ios-sim"
cargo build --target aarch64-apple-ios-sim --$ENV
echo "Building aarch64-apple-darwin"
cargo build --target aarch64-apple-darwin --$ENV

# 创建输出目录
mkdir -p out/aarch64-apple-ios
mkdir -p out/aarch64-apple-ios-sim
mkdir -p out/aarch64-apple-darwin

# 生成绑定
for target in "aarch64-apple-ios" "aarch64-apple-ios-sim" "aarch64-apple-darwin"; do
  echo "为$target生成绑定"
  cargo run \
        --bin uniffi-bindgen generate \
        --library $TARGET_DIR/$target/$ENV/$STATIC_LIB_NAME \
        --language swift \
        --out-dir $OUTPUT_DIR/$target
  mv $OUTPUT_DIR/$target/${PROJECT_NAME}FFI.modulemap $OUTPUT_DIR/$target/module.modulemap
done

# 创建XCFramework
xcodebuild -create-xcframework \
  -library "$TARGET_DIR/aarch64-apple-darwin/$ENV/$STATIC_LIB_NAME" \
  -headers "$OUTPUT_DIR/aarch64-apple-darwin" \
  -library "$TARGET_DIR/aarch64-apple-ios/$ENV/$STATIC_LIB_NAME" \
  -headers "$OUTPUT_DIR/aarch64-apple-ios" \
  -library "$TARGET_DIR/aarch64-apple-ios-sim/$ENV/$STATIC_LIB_NAME" \
  -headers "$OUTPUT_DIR/aarch64-apple-ios-sim" \
  -output $DEST