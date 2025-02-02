#!/bin/bash

build_dir=$1
app_name=$2
app_version=$3

pkg_dir="${build_dir}/pkg/windows"
mkdir -p "${pkg_dir}"

# Copy icon if exists
if [ -f "${WIN_ICON_PATH}" ]; then
    cp "${WIN_ICON_PATH}" "${build_dir}/pkg/windows/"
fi

# Update installer script to include LICENSE
cat > "${pkg_dir}/installer.nsi" << EOF
Name "${app_name}"
OutFile "${build_dir}/bin/${app_name}-v${app_version}-setup.exe"
InstallDir \$PROGRAMFILES\\${app_name}

VIProductVersion "${app_version}.0"
VIAddVersionKey "ProductName" "${app_name}"
VIAddVersionKey "FileDescription" "${APP_DESCRIPTION}"
VIAddVersionKey "LegalCopyright" "${APP_COPYRIGHT}"
VIAddVersionKey "CompanyName" "${APP_DEVELOPER_NAME}"

Section "Install"
    SetOutPath \$INSTDIR
    File "${build_dir}/bin/${app_name}-v${app_version}-amd64-windows.exe"
    File "LICENSE"
    CreateShortCut "\$SMPROGRAMS\\${app_name}.lnk" "\$INSTDIR\\${app_name}.exe"
SectionEnd
EOF

# Build installer if makensis is available
if command -v makensis &> /dev/null; then
    makensis "${pkg_dir}/installer.nsi"
fi
