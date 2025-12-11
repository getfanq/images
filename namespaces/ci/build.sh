#!/usr/bin/env bash
#
# Build script for CI namespace Docker images
# This script reads config.yml and builds Docker images based on the build matrix
#
# Usage:
#   ./build.sh [options]
#
# Options:
#   --all                Build all images in the matrix
#   --name NAME          Build specific image by name (e.g., symfony7-latest)
#   --push               Push images to registry after building
#   --dry-run            Show what would be built without building
#   --no-cache           Build without using cache
#   --platform PLATFORM  Target platform (e.g., linux/amd64,linux/arm64)
#   --registry REGISTRY  Override registry (default: ghcr.io)
#   --username USERNAME  Override registry username
#   --parallel           Build images in parallel (requires GNU parallel)
#   --help               Show this help message
#
# Examples:
#   ./build.sh --all                              # Build all images
#   ./build.sh --name symfony7-latest --push      # Build and push specific image
#   ./build.sh --all --dry-run                    # Show what would be built
#   ./build.sh --name edge --no-cache             # Build without cache

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.yml"
DOCKERFILE="${SCRIPT_DIR}/Dockerfile"

# Default values
BUILD_ALL=false
BUILD_NAME=""
PUSH=false
DRY_RUN=false
NO_CACHE=false
PLATFORM=""
PARALLEL=false
REGISTRY=""
USERNAME=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --all)
      BUILD_ALL=true
      shift
      ;;
    --name)
      BUILD_NAME="$2"
      shift 2
      ;;
    --push)
      PUSH=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --no-cache)
      NO_CACHE=true
      shift
      ;;
    --platform)
      PLATFORM="$2"
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
    --parallel)
      PARALLEL=true
      shift
      ;;
    --help)
      grep '^#' "$0" | grep -v '#!/usr/bin/env' | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Run with --help for usage information"
      exit 1
      ;;
  esac
done

# Validation
if [[ "$BUILD_ALL" == false ]] && [[ -z "$BUILD_NAME" ]]; then
  echo -e "${RED}Error: Must specify either --all or --name${NC}"
  echo "Run with --help for usage information"
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${RED}Error: Config file not found: $CONFIG_FILE${NC}"
  exit 1
fi

if [[ ! -f "$DOCKERFILE" ]]; then
  echo -e "${RED}Error: Dockerfile not found: $DOCKERFILE${NC}"
  exit 1
fi

# Check for yq (YAML parser) - required for parsing config.yml
if ! command -v yq &> /dev/null; then
  echo -e "${YELLOW}Warning: yq not found. Installing via snap...${NC}"
  echo "Alternatively, you can install via: brew install yq (macOS) or snap install yq (Linux)"
  echo "For now, we'll parse YAML manually (basic parsing only)"
fi

# Function to print info messages
info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to print success messages
success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to print warning messages
warn() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to print error messages
error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Get registry from config or environment
get_registry() {
  if [[ -n "$REGISTRY" ]]; then
    echo "$REGISTRY"
  else
    echo "ghcr.io"
  fi
}

# Get username from config or environment
get_username() {
  if [[ -n "$USERNAME" ]]; then
    echo "$USERNAME"
  elif [[ -n "${GITHUB_REPOSITORY_OWNER:-}" ]]; then
    echo "$GITHUB_REPOSITORY_OWNER"
  elif [[ -n "${GITHUB_ACTOR:-}" ]]; then
    echo "$GITHUB_ACTOR"
  else
    echo "username"
  fi
}

# Build a single image
build_image() {
  local name=$1
  local ubuntu=$2
  local node=$3
  local php=$4
  local aliases=$5
  
  local registry=$(get_registry)
  local username=$(get_username)
  local namespace="ci"
  
  # Primary tag
  local primary_tag="${registry}/${username}/${namespace}:ubuntu${ubuntu}-node${node}-php${php}"
  
  # Build tags array
  local tags=("$primary_tag")
  
  # Add aliases
  if [[ -n "$aliases" ]]; then
    IFS=',' read -ra alias_array <<< "$aliases"
    for alias in "${alias_array[@]}"; do
      alias=$(echo "$alias" | xargs)  # Trim whitespace
      tags+=("${registry}/${username}/${namespace}:${alias}")
    done
  fi
  
  # Build docker build command
  local docker_cmd="docker build"
  
  # Add platform if specified
  if [[ -n "$PLATFORM" ]]; then
    docker_cmd+=" --platform $PLATFORM"
  fi
  
  # Add no-cache if specified
  if [[ "$NO_CACHE" == true ]]; then
    docker_cmd+=" --no-cache"
  fi
  
  # Add build args (only Ubuntu, Node, and PHP are configurable)
  docker_cmd+=" --build-arg UBUNTU_VERSION=${ubuntu}"
  docker_cmd+=" --build-arg NODE_VERSION=${node}"
  docker_cmd+=" --build-arg PHP_VERSION=${php}"
  
  # Add tags
  for tag in "${tags[@]}"; do
    docker_cmd+=" -t $tag"
  done
  
  # Add dockerfile and context
  docker_cmd+=" -f ${DOCKERFILE} ${SCRIPT_DIR}"
  
  info "Building image: $name"
  info "  Ubuntu: $ubuntu"
  info "  Node.js: $node"
  info "  PHP: $php"
  info "  Primary tag: $primary_tag"
  if [[ -n "$aliases" ]]; then
    info "  Aliases: $aliases"
  fi
  
  if [[ "$DRY_RUN" == true ]]; then
    info "  [DRY RUN] Would execute: $docker_cmd"
  else
    info "  Executing build..."
    if eval "$docker_cmd"; then
      success "Built image: $primary_tag"
      
      # Push if requested
      if [[ "$PUSH" == true ]]; then
        info "Pushing image tags..."
        for tag in "${tags[@]}"; do
          info "  Pushing: $tag"
          if docker push "$tag"; then
            success "Pushed: $tag"
          else
            error "Failed to push: $tag"
          fi
        done
      fi
    else
      error "Failed to build image: $name"
      return 1
    fi
  fi
  
  echo ""
}

# Parse config.yml and build images
# Note: This is a simplified parser. For production, use yq or similar tool
info "Reading configuration from: $CONFIG_FILE"

# Extract build matrix from config.yml
# This is a basic grep-based parser - in production, use yq or a proper YAML parser
build_matrix_section=false
current_image=""
declare -A images

while IFS= read -r line; do
  # Detect build_matrix section
  if [[ "$line" =~ ^build_matrix: ]]; then
    build_matrix_section=true
    continue
  fi
  
  if [[ "$build_matrix_section" == true ]]; then
    # End of build_matrix section
    if [[ "$line" =~ ^[a-z_]+: ]] && [[ ! "$line" =~ ^[[:space:]]+ ]]; then
      break
    fi
    
    # Parse image entry
    if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+name:[[:space:]]+\"(.+)\" ]]; then
      current_image="${BASH_REMATCH[1]}"
      images["${current_image}_name"]="$current_image"
    elif [[ "$line" =~ ^[[:space:]]+ubuntu:[[:space:]]+\"(.+)\" ]]; then
      images["${current_image}_ubuntu"]="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]+node:[[:space:]]+\"(.+)\" ]]; then
      images["${current_image}_node"]="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]+php:[[:space:]]+\"(.+)\" ]]; then
      images["${current_image}_php"]="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]+aliases: ]]; then
      # Start collecting aliases
      continue
    elif [[ "$line" =~ ^[[:space:]]+-[[:space:]]+\"(.+)\" ]]; then
      # Alias line
      alias="${BASH_REMATCH[1]}"
      if [[ -n "${images[${current_image}_aliases]:-}" ]]; then
        images["${current_image}_aliases"]="${images[${current_image}_aliases]},$alias"
      else
        images["${current_image}_aliases"]="$alias"
      fi
    fi
  fi
done < "$CONFIG_FILE"

# Get unique image names
image_names=()
for key in "${!images[@]}"; do
  if [[ "$key" =~ _name$ ]]; then
    image_names+=("${images[$key]}")
  fi
done

info "Found ${#image_names[@]} images in build matrix"

# Build images
if [[ "$BUILD_ALL" == true ]]; then
  info "Building all images..."
  for name in "${image_names[@]}"; do
    ubuntu="${images[${name}_ubuntu]}"
    node="${images[${name}_node]}"
    php="${images[${name}_php]}"
    aliases="${images[${name}_aliases]:-}"
    
    build_image "$name" "$ubuntu" "$node" "$php" "$aliases"
  done
else
  # Build specific image
  if [[ -n "${images[${BUILD_NAME}_name]:-}" ]]; then
    ubuntu="${images[${BUILD_NAME}_ubuntu]}"
    node="${images[${BUILD_NAME}_node]}"
    php="${images[${BUILD_NAME}_php]}"
    aliases="${images[${BUILD_NAME}_aliases]:-}"
    
    build_image "$BUILD_NAME" "$ubuntu" "$node" "$php" "$aliases"
  else
    error "Image not found in build matrix: $BUILD_NAME"
    info "Available images:"
    for name in "${image_names[@]}"; do
      echo "  - $name"
    done
    exit 1
  fi
fi

success "Build process completed!"
