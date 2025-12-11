#!/usr/bin/env bash
#
# Build all Docker images across all namespaces
#
# Usage:
#   ./build-all.sh [options]
#
# Options:
#   --namespace NAMESPACE    Build only specified namespace (default: all)
#   --push                   Push images after building
#   --dry-run               Show what would be built without building
#   --parallel              Build images in parallel
#   --help                  Show this help message

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source helper libraries
source "${SCRIPT_DIR}/lib/docker-helpers.sh"
source "${SCRIPT_DIR}/lib/version-helpers.sh"
source "${SCRIPT_DIR}/lib/registry-helpers.sh"

# Default values
NAMESPACE=""
PUSH=false
DRY_RUN=false
PARALLEL=false

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
    --push)
      PUSH=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
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
      exit 1
      ;;
  esac
done

# Check Docker
if ! check_docker; then
  echo -e "${RED}Docker check failed${NC}"
  exit 1
fi

echo -e "${BLUE}=== Building Docker Images ===${NC}"
echo ""

# Find all namespaces
NAMESPACES_DIR="${ROOT_DIR}/namespaces"
namespaces=()

if [[ -n "$NAMESPACE" ]]; then
  if [[ -d "${NAMESPACES_DIR}/${NAMESPACE}" ]]; then
    namespaces=("$NAMESPACE")
  else
    echo -e "${RED}Namespace not found: $NAMESPACE${NC}"
    exit 1
  fi
else
  for ns_dir in "${NAMESPACES_DIR}"/*; do
    if [[ -d "$ns_dir" ]] && [[ -f "${ns_dir}/build.sh" ]]; then
      namespaces+=("$(basename "$ns_dir")")
    fi
  done
fi

echo -e "${BLUE}Found ${#namespaces[@]} namespace(s) to build:${NC}"
for ns in "${namespaces[@]}"; do
  echo "  - $ns"
done
echo ""

# Build each namespace
for ns in "${namespaces[@]}"; do
  echo -e "${BLUE}=== Building namespace: $ns ===${NC}"
  
  ns_dir="${NAMESPACES_DIR}/${ns}"
  build_script="${ns_dir}/build.sh"
  
  if [[ ! -f "$build_script" ]]; then
    echo -e "${YELLOW}No build script found for namespace: $ns${NC}"
    continue
  fi
  
  # Build arguments
  build_args="--all"
  
  if [[ "$PUSH" == true ]]; then
    build_args+=" --push"
  fi
  
  if [[ "$DRY_RUN" == true ]]; then
    build_args+=" --dry-run"
  fi
  
  if [[ "$PARALLEL" == true ]]; then
    build_args+=" --parallel"
  fi
  
  # Execute build
  if bash "$build_script" $build_args; then
    echo -e "${GREEN}Successfully built namespace: $ns${NC}"
  else
    echo -e "${RED}Failed to build namespace: $ns${NC}"
    exit 1
  fi
  
  echo ""
done

echo -e "${GREEN}=== All builds completed ===${NC}"
