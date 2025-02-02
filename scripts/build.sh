#!/bin/bash

set -e

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# OS detection
CURRENT_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
CURRENT_ARCH=$(uname -m)
case "$CURRENT_ARCH" in
    x86_64) CURRENT_ARCH="amd64" ;;
    aarch64) CURRENT_ARCH="arm64" ;;
esac

show_help() {
    echo -e "${BLUE}Golang Build Script${NC}"
    echo
    echo -e "Usage: $0 ${YELLOW}[command]${NC} [options]"
    echo
    echo -e "${GREEN}Commands:${NC}"
    echo -e "  ${YELLOW}build${NC}         Execute build process"
    echo -e "  ${YELLOW}platforms${NC}     List available build platforms"
    echo
    echo -e "${GREEN}Options:${NC}"
    echo -e "  ${YELLOW}--help${NC}        Show this help message"
    echo -e "  ${YELLOW}--source${NC}      Build source archive only"
    echo -e "  ${YELLOW}--dist${NC}        Include distribution packages for current OS"
    echo -e "  ${YELLOW}--platforms${NC}   Specify additional target platforms (comma-separated)"
    echo -e "                Format: os/arch (e.g., windows/amd64,linux/arm64)"
    echo -e "  ${YELLOW}--notarize${NC}    Enable macOS notarization with --dist flag (requires build.conf)"
    echo
    echo -e "${GREEN}Examples:${NC}"
    echo -e "  $0 platforms"
    echo -e "  $0 build ${YELLOW}--platforms windows/amd64,linux/amd64${NC}"
    echo -e "  $0 build ${YELLOW}--dist --notarize${NC}"
    echo -e "  $0 build ${YELLOW}--source${NC}"
    echo
    echo -e "${GREEN}Current platform:${NC} ${CURRENT_OS}/${CURRENT_ARCH}"
}

# Show help if no arguments
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

if [ "$1" = "platforms" ]; then
    echo -e "${BLUE}Available Build Platforms${NC}"
    echo -e "\n${GREEN}Operating Systems:${NC}"
    echo -e "  linux"
    echo -e "  darwin"
    echo -e "  windows"
    echo -e "\n${GREEN}Architectures:${NC}"
    echo -e "  amd64    (x86_64)"
    echo -e "  arm64    (aarch64)"
    echo -e "\n${GREEN}Common Combinations:${NC}"
    echo -e "  windows/amd64"
    echo -e "  linux/amd64"
    echo -e "  linux/arm64"
    echo -e "  darwin/amd64"
    echo -e "  darwin/arm64"
    exit 0
fi

# Check for build command
if [ "$1" != "build" ]; then
    show_help
    exit 1
fi
shift

# Check for build.conf
# Source build.conf if it exists
if [ -f "build.conf" ]; then
    source build.conf
else
    echo -e "${RED}Warning: build.conf not found. Using default values.${NC}\n"
fi

# List of platforms to build for
default_platforms=("${CURRENT_OS}/${CURRENT_ARCH}")
selected_platforms=()

# Parse command line arguments
build_source=false
build_dist=false
notarize=false


while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --source)
            build_source=true
            shift
            ;;
        --dist)
            build_dist=true
            shift
            ;;
        --platforms)
            IFS=',' read -ra selected_platforms <<< "$2"
            shift 2
            ;;
        --notarize)
            notarize=true
            shift
            ;;
        *)
            echo "Usage: $0 [--source] [--dist] [--platforms os/arch,...] [--notarize]"
            exit 1
            ;;
    esac
done

# If no platforms specified, use defaults
if [ ${#selected_platforms[@]} -eq 0 ]; then
    selected_platforms=("${default_platforms[@]}")
fi


# Get the current timestamp
timestamp=$(date "+%Y-%m-%d %H:%M:%S")
buildstamp=$(date +%y%m%d%H%M%S)



# Extract with patterns that match const block style
app_name=$(grep 'AppName.*=' config.go | awk -F'"' '{print $2}')
app_version=$(grep 'AppVersion.*=' config.go | awk -F'"' '{print $2}')

echo -e "${BLUE}┌───────────────────────────────────────────┐"
echo -e "│          STEP 1: INITIALIZATION           │"
echo -e "└───────────────────────────────────────────┘${NC}\n"
echo -e "    ${YELLOW}App Name:    ${NC}$app_name"
echo -e "    ${YELLOW}Version:     ${NC}$app_version"
echo -e "    ${YELLOW}Build:       ${NC}$buildstamp ($timestamp)"
echo -e "    ${YELLOW}Platforms:   ${NC}${selected_platforms[*]}\n"


# Create the build folder if it doesn't exist
echo -e "    ${YELLOW}...Creating build folders${NC}\n"
mkdir -p build

# Create the main build directory structure
build_dir="build/v${app_version}_${buildstamp}"
mkdir -p "${build_dir}"


echo -e "${BLUE}┌───────────────────────────────────────────┐"
echo -e "│       STEP 2: BUILD ENVIRONMENT SETUP     │"
echo -e "└───────────────────────────────────────────┘${NC}\n"
echo -e "    ${YELLOW}Build Directory:${NC} ${build_dir}"

# Source code archiving
echo -e "    ${YELLOW}Copying LICENSE.txt...${NC}"
cp LICENSE.txt "${build_dir}"

if [ "$build_source" = true ]; then
    source_archive="${app_name}-v${app_version}-src.tar.gz"
    tar -czf "${build_dir}/${source_archive}" --exclude="build" ./*
    echo -e "    ${GREEN}✓ Source files archived:${NC} ${source_archive}\n"
    goto_build_complete=true
else
    # For full builds, create the complete directory structure
    mkdir -p "${build_dir}/bin"
    mkdir -p "${build_dir}/src"

    # Source code archiving in src directory
    source_archive="${app_name}-v${app_version}-src.tar.gz"
    tar -czf "${build_dir}/src/${source_archive}" --exclude="build" ./*
    echo -e "    ${GREEN}✓ Source files archived:${NC} ${source_archive}\n"
fi



# If only source archive was requested, skip the rest.
if [ "$build_source" = true ]; then
    goto_build_complete=true
fi


if [ "$goto_build_complete" != true ]; then
    echo -e "${BLUE}┌───────────────────────────────────────────┐"
    echo -e "│         STEP 3: BUILDING BINARIES         │"
    echo -e "└───────────────────────────────────────────┘${NC}"

    for platform in "${selected_platforms[@]}"; do
        # Extract OS and architecture
        IFS="/" read -r os arch <<< "$platform"

        # Build the binary
        binary_name="${app_name}-v${app_version}-${arch}-${os}"
        [[ "$os" = "windows" ]] && binary_name+=".exe"

        echo -e "\n    ${YELLOW}Target: ${os}/${arch}${NC}"
        echo -e "    Building ${binary_name}..."
        GOOS=$os GOARCH=$arch go build -o "${build_dir}/bin/$binary_name"
        echo -e "    ${GREEN}✓ Build successful: ${NC}${build_dir}/bin/$binary_name"
    done

    if $build_dist; then
        echo -e "\n${BLUE}┌───────────────────────────────────────────┐"
        echo -e "│     STEP 4: BUILDING OS DISTRIBUTABLE     │"
        echo -e "└───────────────────────────────────────────┘${NC}"

        mkdir -p "${build_dir}/pkg"

        case "$CURRENT_OS" in
            linux)
                echo -e "\n    ${YELLOW}Building Linux package...${NC}"
                source scripts/package/linux.sh "${build_dir}" "${app_name}" "${app_version}"
                echo -e "\n    ${GREEN}✓ Linux package built${NC}"
                ;;
            darwin)
                echo -e "\n    ${YELLOW}Building macOS package...${NC}"
                if [ "$notarize" = true ]; then
                    source scripts/package/macos.sh "${build_dir}" "${app_name}" "${app_version}" "${notarize}"
                    echo -e "\n    ${GREEN}✓ macOS package built and notarized${NC}"
                else
                    source scripts/package/macos.sh "${build_dir}" "${app_name}" "${app_version}"
                    echo -e "\n    ${GREEN}✓ macOS packages built and codesigned${NC}"
                fi
                ;;
            windows)
                echo -e "\n    ${YELLOW}Building Windows package...${NC}"
                source scripts/package/windows.sh "${build_dir}" "${app_name}" "${app_version}"
                echo -e "\n    ${GREEN}✓ Windows package built${NC}"
                ;;
        esac

        # Generate checksums
        cd "${build_dir}/bin"
        sha256sum -- * > checksums.txt
        echo -e "    ${GREEN}✓ Checksums generated${NC}"
        echo -e "\n    ${YELLOW}Checksums:${NC}"
        cat checksums.txt | sed 's/^/      /'
        cd - > /dev/null
    fi
fi


echo -e "\n${GREEN}┌───────────────────────────────────────────┐"
echo -e "│              BUILD COMPLETE!              │"
echo -e "└───────────────────────────────────────────┘${NC}"

echo -e "\n    ${GREEN}✓ Build complete!${NC}\n    Output: ${build_dir}${NC}\n"
