#!/usr/bin/env bash
#
# Docker helper functions for building and managing Docker images

# Check if Docker is installed and running
check_docker() {
  if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed"
    return 1
  fi
  
  if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running"
    return 1
  fi
  
  return 0
}

# Check if Docker Buildx is available
check_buildx() {
  if ! docker buildx version &> /dev/null; then
    echo "Warning: Docker Buildx is not available"
    return 1
  fi
  return 0
}

# Login to Docker registry
docker_login() {
  local registry=$1
  local username=$2
  local token=${3:-${REGISTRY_TOKEN:-${GITHUB_TOKEN:-}}}
  
  if [[ -z "$token" ]]; then
    echo "Error: No authentication token provided"
    return 1
  fi
  
  echo "Logging in to $registry as $username..."
  echo "$token" | docker login "$registry" -u "$username" --password-stdin
}

# Logout from Docker registry
docker_logout() {
  local registry=$1
  docker logout "$registry"
}

# Build Docker image with BuildKit
docker_build_with_buildkit() {
  DOCKER_BUILDKIT=1 docker build "$@"
}

# Tag Docker image
docker_tag_image() {
  local source_tag=$1
  local target_tag=$2
  docker tag "$source_tag" "$target_tag"
}

# Push Docker image
docker_push_image() {
  local tag=$1
  docker push "$tag"
}

# Check if image exists locally
docker_image_exists() {
  local tag=$1
  docker image inspect "$tag" &> /dev/null
}

# Remove Docker image
docker_remove_image() {
  local tag=$1
  docker rmi "$tag"
}

# Prune Docker system
docker_prune() {
  docker system prune -af --volumes
}

# Get image size
docker_image_size() {
  local tag=$1
  docker image inspect "$tag" --format='{{.Size}}' | numfmt --to=iec-i --suffix=B
}

# Run smoke test on image
docker_smoke_test() {
  local tag=$1
  shift
  local commands=("$@")
  
  echo "Running smoke tests on $tag..."
  for cmd in "${commands[@]}"; do
    echo "  Testing: $cmd"
    if ! docker run --rm "$tag" bash -c "$cmd" &> /dev/null; then
      echo "  ✗ Failed: $cmd"
      return 1
    fi
    echo "  ✓ Passed: $cmd"
  done
  
  echo "All smoke tests passed!"
  return 0
}

# Export function for use in other scripts
export -f check_docker
export -f check_buildx
export -f docker_login
export -f docker_logout
export -f docker_build_with_buildkit
export -f docker_tag_image
export -f docker_push_image
export -f docker_image_exists
export -f docker_remove_image
export -f docker_prune
export -f docker_image_size
export -f docker_smoke_test
