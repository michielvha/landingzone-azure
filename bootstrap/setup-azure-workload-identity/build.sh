#!/bin/bash
# Build script for multiple platforms

set -e

VERSION=${VERSION:-"1.0.0"}
BINARY_NAME="setup-azure-workload-identity"
BUILD_DIR="bin"

echo "Building ${BINARY_NAME} v${VERSION}"
echo "======================================="

mkdir -p ${BUILD_DIR}

# Build for multiple platforms
platforms=(
    "linux/amd64"
    "linux/arm64"
    "darwin/amd64"
    "darwin/arm64"
    "windows/amd64"
)

for platform in "${platforms[@]}"; do
    platform_split=(${platform//\// })
    GOOS=${platform_split[0]}
    GOARCH=${platform_split[1]}
    
    output_name="${BINARY_NAME}-${GOOS}-${GOARCH}"
    
    if [ $GOOS = "windows" ]; then
        output_name+='.exe'
    fi
    
    echo "Building for ${GOOS}/${GOARCH}..."
    
    env GOOS=$GOOS GOARCH=$GOARCH go build \
        -ldflags "-X main.version=${VERSION}" \
        -o "${BUILD_DIR}/${output_name}" \
        .
    
    if [ $? -ne 0 ]; then
        echo "Failed to build for ${GOOS}/${GOARCH}"
        exit 1
    fi
done

echo ""
echo "✅ Build complete! Binaries in ${BUILD_DIR}/"
ls -lh ${BUILD_DIR}/

# Create archives
echo ""
echo "Creating archives..."
cd ${BUILD_DIR}

for file in ${BINARY_NAME}-*; do
    if [[ $file == *.exe ]]; then
        # Windows: zip
        zip "${file%.exe}.zip" "$file"
        rm "$file"
    else
        # Unix: tar.gz
        tar czf "${file}.tar.gz" "$file"
        rm "$file"
    fi
done

echo ""
echo "✅ Archives created!"
ls -lh
