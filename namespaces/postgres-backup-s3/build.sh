#!/usr/bin/env bash
#
# Build script for postgres-backup-s3 namespace Docker image
#
# Usage:
#   ./build.sh [options]
#
# Options:
#   --all                Build all images in the matrix (single image in this namespace)
#   --name NAME          Build specific image by name (e.g., ubuntu24.04)
#   --push               Push image to registry after building
#   --dry-run            Show what would be built without building
#   --no-cache           Build without using cache
#   --platform PLATFORM  Target platform (e.g., linux/amd64,linux/arm64)
#   --registry REGISTRY  Override registry (default: ghcr.io)
#   --username USERNAME  Override registry username
#   --parallel           No-op for this namespace (only one image)
#   --help               Show this help message
#
# Examples:
#   ./build.sh --all                         # Build the image
#   ./build.sh --name ubuntu24.04 --push     # Build and push
#   ./build.sh --all --dry-run               # Show what would be built
#   ./build.sh --name ubuntu24.04 --no-cache # Build without cache

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

# Logging helpers
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Get registry
get_registry() {
  if [[ -n "$REGISTRY" ]]; then
    echo "$REGISTRY"
  else
    echo "ghcr.io"
  fi
}

# Get username
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

# Build the image
build_image() {
  local name=$1
  local ubuntu=$2
  local postgres=$3

  local registry
  registry=$(get_registry)
  local username
  username=$(get_username)
  local namespace="postgres-backup-s3"

  # Tag: ubuntu{version}
  local primary_tag="${registry}/${username}/${namespace}:${name}"

  local docker_cmd="docker build"

  if [[ -n "$PLATFORM" ]]; then
    docker_cmd+=" --platform $PLATFORM"
  fi

  if [[ "$NO_CACHE" == true ]]; then
    docker_cmd+=" --no-cache"
  fi

  docker_cmd+=" --build-arg UBUNTU_VERSION=${ubuntu}"
  docker_cmd+=" --build-arg POSTGRES_VERSION=${postgres}"
  docker_cmd+=" -t ${primary_tag}"
  docker_cmd+=" -f ${DOCKERFILE} ${SCRIPT_DIR}"

  info "Building image: $name"
  info "  Ubuntu:     $ubuntu"
  info "  PostgreSQL: $postgres"
  info "  Tag:        $primary_tag"

  if [[ "$DRY_RUN" == true ]]; then
    info "  [DRY RUN] Would execute: $docker_cmd"
  else
    info "  Executing build..."
    if eval "$docker_cmd"; then
      success "Built image: $primary_tag"

      if [[ "$PUSH" == true ]]; then
        info "Pushing image: $primary_tag"
        if docker push "$primary_tag"; then
          success "Pushed: $primary_tag"
        else
          error "Failed to push: $primary_tag"
        fi
      fi
    else
      error "Failed to build image: $name"
      return 1
    fi
  fi

  echo ""
}

# Parse build matrix from config.yml
info "Reading configuration from: $CONFIG_FILE"

build_matrix_section=false
current_image=""
declare -A images

while IFS= read -r line; do
  if [[ "$line" =~ ^build_matrix: ]]; then
    build_matrix_section=true
    continue
  fi

  if [[ "$build_matrix_section" == true ]]; then
    # End of build_matrix section when a non-indented key appears
    if [[ "$line" =~ ^[a-z_]+: ]] && [[ ! "$line" =~ ^[[:space:]]+ ]]; then
      break
    fi

    if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+name:[[:space:]]+\"(.+)\" ]]; then
      current_image="${BASH_REMATCH[1]}"
      images["${current_image}_name"]="$current_image"
    elif [[ "$line" =~ ^[[:space:]]+ubuntu:[[:space:]]+\"(.+)\" ]]; then
      images["${current_image}_ubuntu"]="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]+postgres:[[:space:]]+\"(.+)\" ]]; then
      images["${current_image}_postgres"]="${BASH_REMATCH[1]}"
    fi
  fi
done < "$CONFIG_FILE"

# Collect image names
image_names=()
for key in "${!images[@]}"; do
  if [[ "$key" =~ _name$ ]]; then
    image_names+=("${images[$key]}")
  fi
done

info "Found ${#image_names[@]} image(s) in build matrix"

if [[ "$BUILD_ALL" == true ]]; then
  info "Building all images..."
  for name in "${image_names[@]}"; do
    ubuntu="${images[${name}_ubuntu]}"
    postgres="${images[${name}_postgres]}"
    build_image "$name" "$ubuntu" "$postgres"
  done
else
  if [[ -n "${images[${BUILD_NAME}_name]:-}" ]]; then
    ubuntu="${images[${BUILD_NAME}_ubuntu]}"
    postgres="${images[${BUILD_NAME}_postgres]}"
    build_image "$BUILD_NAME" "$ubuntu" "$postgres"
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
