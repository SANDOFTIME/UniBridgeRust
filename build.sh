#!/bin/bash

# Check if project name is provided
if [ -z "$1" ]; then
  echo "Please provide a project name."
  echo "Usage: ./setup_flutter_rust.sh project_name"
  exit 1
fi

PROJECT_NAME=$1

# Check if build script files exist in the current directory
if [ ! -f "./ios_build.sh" ] || [ ! -f "./android_build.sh" ]; then
  echo "Error: ios_build.sh and/or android_build.sh not found in the current directory."
  exit 1
fi

# Step 1: Create test project
flutter_rust_bridge_codegen create $PROJECT_NAME

# Step 2-9: Set up the Rust directory structure
cd $PROJECT_NAME
cd rust

# Create the libraries
cargo new --lib data_core
cargo new --lib uniffi_bridge

# Create flutter_bridge directory
mkdir -p flutter_bridge

# Move everything except flutter_bridge to flutter_bridge
find . -maxdepth 1 ! -name . ! -name flutter_bridge -exec mv {} flutter_bridge \;

# Create .cargo directory and config in uniffi_bridge
mkdir -p uniffi_bridge/.cargo
cat > uniffi_bridge/.cargo/config.toml << 'EOF'
[build]
target-dir = "target"
EOF

# Copy build scripts to uniffi_bridge from the script directory
cp ../../ios_build.sh uniffi_bridge/
cp ../../android_build.sh uniffi_bridge/

# Make the scripts executable
chmod +x uniffi_bridge/ios_build.sh
chmod +x uniffi_bridge/android_build.sh

# Create empty data_core.udl file in uniffi_bridge/src
touch uniffi_bridge/src/data_core.udl

# Create uniffi-bindgen.rs file in uniffi_bridge
cat > uniffi_bridge/uniffi-bindgen.rs << 'EOF'
fn main() {
    uniffi::uniffi_bindgen_main()
}
EOF

# Update the uniffi_bridge Cargo.toml with the requested content
cat > uniffi_bridge/Cargo.toml << 'EOF'
[package]
name = "uniffi_bridge"
version = "0.1.0"
edition = "2021"

[dependencies]
uniffi = { version = "0.29.1", features = [ "cli" ] }

[build-dependencies]
uniffi = { version = "0.29.1", features = [ "build" ] }

[lib]
crate-type = ["cdylib", "staticlib"]

[[bin]]
name = "uniffi-bindgen"
path = "uniffi-bindgen.rs"
EOF

# Create the workspace Cargo.toml
cat > Cargo.toml << 'EOF'
[package]
name = "rust_balance"
version = "0.1.0"
edition = "2021"
publish = false

[lib]
path = "flutter_bridge/src/lib.rs"

[workspace]
members = [
  "data_core",
  "flutter_bridge",
  "uniffi_bridge"
]
EOF

# Step 10-12: Update paths in configuration files
cd ..

# Update flutter_rust_bridge.yaml
sed -i.bak 's|rust_root: rust|rust_root: rust/flutter_bridge|g' flutter_rust_bridge.yaml
rm flutter_rust_bridge.yaml.bak 2>/dev/null

# Update paths in rust_builder files
find ./rust_builder -type f -exec grep -l "../../rust" {} \; | xargs sed -i.bak 's|../../rust|../../rust/flutter_bridge|g'
find ./rust_builder -name "*.bak" -delete

echo "Setup complete for $PROJECT_NAME project!"
