#!/bin/bash

build_dir=$1
app_name=$2
app_version=$3

# Create DEB package structure
pkg_dir="${build_dir}/pkg/linux"
mkdir -p "${pkg_dir}/DEBIAN"
mkdir -p "${pkg_dir}/usr/local/bin"
mkdir -p "${pkg_dir}/usr/share/applications"

# Add LICENSE directory
mkdir -p "${pkg_dir}/usr/share/doc/${app_name}"
cp "LICENSE.txt" "${pkg_dir}/usr/share/doc/${app_name}/"

# Copy binary
cp "${build_dir}/bin/${app_name}-v${app_version}-amd64-linux" "${pkg_dir}/usr/local/bin/${app_name}"

# Create control file using build.conf values
cat > "${pkg_dir}/DEBIAN/control" << EOF
Package: ${app_name}
Version: ${app_version}
Section: ${LINUX_CATEGORY:-utils}
Priority: optional
Architecture: amd64
Maintainer: ${MAINTAINER_NAME:-Unknown} <${MAINTAINER_EMAIL:-none@example.com}>
Description: ${APP_DESCRIPTION:-A system tray application}
Depends: ${LINUX_DEPENDENCIES:-}
EOF

# Create desktop entry
cat > "${pkg_dir}/usr/share/applications/${app_name}.desktop" << EOF
[Desktop Entry]
Name=${app_name}
Exec=/usr/local/bin/${app_name}
Type=Application
Categories=${LINUX_CATEGORY:-System};
EOF

# Build DEB package
dpkg-deb --build "${pkg_dir}" "${build_dir}/bin/${app_name}-v${app_version}-amd64.deb"
