#!/bin/bash

# Script to recursively find and extract .7z files using 7-zip
# Usage: ./extract_7z.sh <search_directory> <output_directory>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if 7z is installed
if ! command -v 7z &> /dev/null; then
    echo -e "${RED}Error: 7z (p7zip) is not installed.${NC}"
    echo "Install it with: sudo apt install p7zip-full (Debian/Ubuntu)"
    echo "               : sudo yum install p7zip (RHEL/CentOS)"
    exit 1
fi

# Check arguments
if [ $# -lt 2 ]; then
    echo -e "${YELLOW}Usage: $0 <search_directory> <output_directory>${NC}"
    echo ""
    echo "Arguments:"
    echo "  search_directory  - Directory to search for .7z files recursively"
    echo "  output_directory  - Directory where files will be extracted"
    echo ""
    echo "Example: $0 /path/to/archives /path/to/extracted"
    exit 1
fi

SEARCH_DIR="$1"
OUTPUT_DIR="$2"

# Validate search directory
if [ ! -d "$SEARCH_DIR" ]; then
    echo -e "${RED}Error: Search directory '$SEARCH_DIR' does not exist.${NC}"
    exit 1
fi

# Create output directory if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
    echo -e "${YELLOW}Creating output directory: $OUTPUT_DIR${NC}"
    mkdir -p "$OUTPUT_DIR"
fi

# Convert to absolute paths
SEARCH_DIR=$(realpath "$SEARCH_DIR")
OUTPUT_DIR=$(realpath "$OUTPUT_DIR")

echo -e "${GREEN}Searching for .7z files in: $SEARCH_DIR${NC}"
echo -e "${GREEN}Extracting to: $OUTPUT_DIR${NC}"
echo ""

# Counter for extracted files
count=0
failed=0

# Find and extract all .7z files
while IFS= read -r -d '' archive; do
    echo -e "${YELLOW}Extracting: $archive${NC}"
    
    # Get the base name without extension for subfolder
    basename=$(basename "$archive" .7z)
    
    # Create a subfolder for each archive to avoid conflicts
    extract_path="$OUTPUT_DIR/$basename"
    mkdir -p "$extract_path"
    
    # Extract the archive
    if 7z x -y -o"$extract_path" "$archive"; then
        echo -e "${GREEN}✓ Successfully extracted: $basename${NC}"
        ((count++))
    else
        echo -e "${RED}✗ Failed to extract: $archive${NC}"
        ((failed++))
    fi
    echo ""
done < <(find "$SEARCH_DIR" -type f -iname "*.7z" -print0)

# Summary
echo "========================================"
echo -e "${GREEN}Extraction complete!${NC}"
echo -e "Successfully extracted: ${GREEN}$count${NC} archive(s)"
if [ $failed -gt 0 ]; then
    echo -e "Failed: ${RED}$failed${NC} archive(s)"
fi
echo "Output directory: $OUTPUT_DIR"

