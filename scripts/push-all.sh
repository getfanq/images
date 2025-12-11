#!/usr/bin/env bash
#
# Push all Docker images to registry
#
# Usage:
#   ./push-all.sh [options]
#
# Options:
#   --namespace NAMESPACE    Push only specified namespace (default: all)
#   --registry REGISTRY      Target registry (default: ghcr.io)
#   --username USERNAME      Registry username
#   --token TOKEN           Registry authentication token
#   --dry-run               Show what would be pushed without pushing
#   --help                  Show this help message

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source helper libraries
source "${SCRIPT_DIR}/lib/docker-helpers.sh"
source "${SCRIPT_DIR}/lib/registry-helpers.sh"

# Default values
NAMESPACE=""
REGISTRY=""
USERNAME=""
TOKEN=""
DRY_RUN=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --registry)
      REGISTRY="$2"
      shift 2
      ;;
    --username)
      USERNAME="$2"
      shift 2
      ;;
    --token)
      TOKEN="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      grep '^#' "$0" | grep -v '#!/usr/bin/env' | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Get registry and username
REGISTRY=$(get_registry "$REGISTRY")
USERNAME=$(get_registry_username "$USERNAME")
TOKEN=$(get_registry_token "$TOKEN")

echo -e "${BLUE}=== Pushing Docker Images ===${NC}"
echo "Registry: $REGISTRY"
echo "Username: $USERNAME"
echo ""

# Validate credentials
if [[ "$DRY_RUN" == false ]]; then
  if ! validate_registry_credentials "$REGISTRY" "$USERNAME" "$TOKEN"; then
    echo -e "${RED}Invalid registry credentials${NC}"
    exit 1
  fi
  
  # Login to registry
  if ! registry_login "$REGISTRY" "$USERNAME" "$TOKEN"; then
    echo -e "${RED}Failed to login to registry${NC}"
    exit 1
  fi
  
  echo -e "${GREEN}Successfully logged in to $REGISTRY${NC}"
  echo ""
fi

# Find all local images matching the pattern
namespace_pattern="${USERNAME}"
if [[ -n "$NAMESPACE" ]]; then
  namespace_pattern="${USERNAME}/${NAMESPACE}"
fi

echo -e "${BLUE}Finding images matching: ${REGISTRY}/${namespace_pattern}${NC}"
images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^${REGISTRY}/${namespace_pattern}" || true)

if [[ -z "$images" ]]; then
  echo -e "${YELLOW}No images found matching pattern${NC}"
  exit 0
fi

# Count images
image_count=$(echo "$images" | wc -l)
echo -e "${BLUE}Found $image_count image(s) to push${NC}"
echo ""

# Push each image
pushed=0
failed=0

while IFS= read -r image; do
  echo -e "${BLUE}Pushing: $image${NC}"
  
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY RUN] Would push: $image${NC}"
    ((pushed++))
  else
    if docker_push_image "$image"; then
      echo -e "${GREEN}Successfully pushed: $image${NC}"
      ((pushed++))
    else
      echo -e "${RED}Failed to push: $image${NC}"
      ((failed++))
    fi
  fi
  echo ""
done <<< "$images"

# Summary
echo -e "${BLUE}=== Push Summary ===${NC}"
echo "Total images: $image_count"
echo -e "${GREEN}Successfully pushed: $pushed${NC}"
if [[ $failed -gt 0 ]]; then
  echo -e "${RED}Failed: $failed${NC}"
fi

# Logout
if [[ "$DRY_RUN" == false ]]; then
  docker_logout "$REGISTRY"
fi

if [[ $failed -gt 0 ]]; then
  exit 1
fi

echo -e "${GREEN}=== All images pushed successfully ===${NC}"
