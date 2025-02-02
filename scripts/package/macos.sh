#!/bin/bash

build_dir=$1
app_name=$2
app_version=$3
notarize=$4

# Create app bundle structure
app_dir="${build_dir}/pkg/macos/${app_name}.app"
mkdir -p "${app_dir}/Contents/MacOS"
mkdir -p "${app_dir}/Contents/Resources"

# Copy binary
cp "${build_dir}/bin/${app_name}-v${app_version}-arm64-darwin" "${app_dir}/Contents/MacOS/${app_name}"


# Copy LICENSE to Resources
cp "LICENSE.txt" "${app_dir}/Contents/Resources/"

# Copy icon if exists
if [ -f "${APPLE_ICON_PATH}" ]; then
    cp "${APPLE_ICON_PATH}" "${app_dir}/Contents/Resources/AppIcon.icns"
fi

# Set proper permissions
chmod 755 "${app_dir}/Contents/MacOS/${app_name}"

# Create Info.plist
cat > "${app_dir}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${app_name}</string>
    <key>CFBundleIdentifier</key>
    <string>${APPLE_ORGANIZATION_ID:-com.example}.${app_name}</string>
    <key>CFBundleName</key>
    <string>${app_name}</string>
    <key>CFBundleVersion</key>
    <string>${app_version}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLIconFile</key>
            <string>AppIcon</string>
        </dict>
    </array>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSHumanReadableCopyright</key>
    <string>${APP_COPYRIGHT:-© $(date +%Y) ${APPLE_ORGANIZATION_ID:-Example Inc}}</string>
</dict>
</plist>
EOF

# Validate Info.plist
plutil -lint "${app_dir}/Contents/Info.plist"

# Create Entitlements
cat > "entitlements.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
EOF

# Sign the application
if [ "$notarize" = true ]; then
    codesign --force --options runtime --sign "${APPLE_DEVELOPER_ID}" --entitlements entitlements.plist "${app_dir}"
else
    codesign --force --deep --entitlements entitlements.plist --sign - "${app_dir}"
fi

# Verify Signature
codesign --verify --deep --verbose=4 "${app_dir}"

echo "✅ macOS .app build complete!"
