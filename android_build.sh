#!/bin/bash
set -e  # 遇到错误立即退出

# =============== 配置区域 - 根据你的项目调整这些变量 ===============
# Rust 项目路径
RUST_PROJECT_PATH="."
# UDL 文件路径（相对于 Rust 项目路径）
UDL_FILE="src/data_core.udl"
# 生成的库名称（不带 lib 前缀和 .so 后缀）
LIB_NAME="data_core"
# Android 项目路径
ANDROID_PROJECT_PATH="../../android"
# Android jniLibs 路径（相对于 Android 项目路径）
JNILIBS_PATH="app/src/main/jniLibs"
# Kotlin 绑定文件目标路径（相对于 Android 项目路径）
KOTLIN_BINDINGS_PATH="app/src/main/java"
# 要构建的 Android ABIs
ANDROID_ABIS=("arm64-v8a" "armeabi-v7a" "x86" "x86_64")
# =============== 配置结束 ===============

echo "=== 开始构建和部署过程 ==="

# 确保工作目录
cd "$(dirname "$0")"

# 1. 使用 cargo-ndk 构建 Rust 库
echo "=== 步骤 1: 使用 cargo-ndk 构建 Rust 库 ==="
cd "$RUST_PROJECT_PATH"

# 检查是否安装了 cargo-ndk
if ! command -v cargo ndk &> /dev/null; then
    echo "错误: cargo-ndk 未安装。请执行 'cargo install cargo-ndk' 安装它。"
    exit 1
fi

# 构建所有平台
TARGETS=""
for ABI in "${ANDROID_ABIS[@]}"; do
    TARGETS="$TARGETS -t $ABI"
done

# 执行构建
echo "正在为以下架构构建: ${ANDROID_ABIS[*]}"
cargo ndk $TARGETS build --release

# 确认构建成功
if [ $? -ne 0 ]; then
    echo "Rust 库构建失败！"
    exit 1
fi

echo "Rust 库构建成功！"

# 2. 生成 Kotlin 绑定文件
echo "=== 步骤 2: 生成 Kotlin 绑定文件 ==="
# 创建临时目录用于存放生成的绑定文件
TEMP_BINDINGS_DIR="out"
mkdir -p "$TEMP_BINDINGS_DIR"

# 使用 uniffi-bindgen 生成 Kotlin 绑定
cargo run --bin uniffi-bindgen generate --library target/aarch64-linux-android/release/libdata_core.so --language kotlin --out-dir "$TEMP_BINDINGS_DIR"
if [ $? -ne 0 ]; then
    echo "Kotlin 绑定文件生成失败！"
    exit 1
fi

echo "Kotlin 绑定文件生成成功！"

# 3. 将 .so 文件移动到 Android 项目的 jniLibs 文件夹
echo "=== 步骤 3: 将 .so 文件移动到 Android jniLibs 文件夹 ==="
cd "$(dirname "$0")"  # 回到脚本目录
mkdir -p "$ANDROID_PROJECT_PATH/$JNILIBS_PATH"

# 为每个 ABI 创建目录并复制 .so 文件
for ABI in "${ANDROID_ABIS[@]}"; do
    TARGET_DIR="$ANDROID_PROJECT_PATH/$JNILIBS_PATH/$ABI"
    mkdir -p "$TARGET_DIR"
    
    # 根据 ABI 确定 Rust 目标三元组
    case "$ABI" in
        "arm64-v8a")
            RUST_TARGET="aarch64-linux-android"
            ;;
        "armeabi-v7a")
            RUST_TARGET="armv7-linux-androideabi"
            ;;
        "x86")
            RUST_TARGET="i686-linux-android"
            ;;
        "x86_64")
            RUST_TARGET="x86_64-linux-android"
            ;;
        *)
            echo "未知的 ABI: $ABI"
            continue
            ;;
    esac
    
    # 复制 .so 文件
    SO_FILE="$RUST_PROJECT_PATH/target/$RUST_TARGET/release/lib$LIB_NAME.so"
    if [ -f "$SO_FILE" ]; then
        cp "$SO_FILE" "$TARGET_DIR/"
        echo "已复制 $SO_FILE 到 $TARGET_DIR/"
    else
        echo "警告: 找不到 $SO_FILE"
    fi
done

# 4. 将 Kotlin 绑定文件移动到指定文件夹 - 添加删除旧文件的逻辑
echo "=== 步骤 4: 将 Kotlin 绑定文件移动到指定文件夹 ==="
mkdir -p "$ANDROID_PROJECT_PATH/$KOTLIN_BINDINGS_PATH"

# 先删除现有的绑定文件，避免冲突
echo "删除现有的绑定文件..."
find "$ANDROID_PROJECT_PATH" -name "${LIB_NAME}.kt" -delete

# 找到生成的 Kotlin 文件并复制
KOTLIN_FILES=("$TEMP_BINDINGS_DIR"/uniffi/$LIB_NAME/*.kt)
if [ ${#KOTLIN_FILES[@]} -eq 0 ]; then
    echo "错误: 找不到生成的 Kotlin 绑定文件！"
    exit 1
fi

for FILE in "${KOTLIN_FILES[@]}"; do
    cp "$FILE" "$ANDROID_PROJECT_PATH/$KOTLIN_BINDINGS_PATH/"
    echo "已复制 $FILE 到 $ANDROID_PROJECT_PATH/$KOTLIN_BINDINGS_PATH/"
done

# 清理临时目录
rm -rf "$TEMP_BINDINGS_DIR"

echo "=== 构建和部署过程完成 ==="
echo "现在你可以在 Android 项目中使用 Rust 库了！"