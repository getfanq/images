#!/usr/bin/env bash
#
# Registry helper functions for interacting with Docker registries

# Get registry from environment or config
get_registry() {
  local registry=${REGISTRY:-${1:-ghcr.io}}
  echo "$registry"
}

# Get username from environment
get_registry_username() {
  local username=${REGISTRY_USERNAME:-${GITHUB_REPOSITORY_OWNER:-${GITHUB_ACTOR:-${1:-username}}}}
  echo "$username"
}

# Get authentication token
get_registry_token() {
  local token=${REGISTRY_TOKEN:-${GITHUB_TOKEN:-${1:-}}}
  echo "$token"
}

# Build full image name
build_image_name() {
  local registry=$1
  local username=$2
  local namespace=$3
  local tag=$4
  
  echo "${registry}/${username}/${namespace}:${tag}"
}

# Parse image name into components
parse_image_name() {
  local image=$1
  local registry username namespace tag
  
  # Extract registry (before first /)
  registry=$(echo "$image" | cut -d/ -f1)
  
  # Extract username (second component)
  username=$(echo "$image" | cut -d/ -f2)
  
  # Extract namespace and tag
  local remainder=$(echo "$image" | cut -d/ -f3-)
  namespace=$(echo "$remainder" | cut -d: -f1)
  tag=$(echo "$remainder" | cut -d: -f2)
  
  echo "REGISTRY=$registry"
  echo "USERNAME=$username"
  echo "NAMESPACE=$namespace"
  echo "TAG=$tag"
}

# Check if registry is GitHub Container Registry
is_ghcr() {
  local registry=$1
  [[ "$registry" == "ghcr.io" ]]
}

# Check if registry is Docker Hub
is_dockerhub() {
  local registry=$1
  [[ "$registry" == "docker.io" ]] || [[ "$registry" == "index.docker.io" ]]
}

# Check if registry is AWS ECR
is_ecr() {
  local registry=$1
  [[ "$registry" =~ \.amazonaws\.com$ ]]
}

# Login to appropriate registry
registry_login() {
  local registry=$1
  local username=$2
  local token=$3
  
  if is_ghcr "$registry"; then
    echo "Logging in to GitHub Container Registry..."
    echo "$token" | docker login ghcr.io -u "$username" --password-stdin
  elif is_dockerhub "$registry"; then
    echo "Logging in to Docker Hub..."
    echo "$token" | docker login -u "$username" --password-stdin
  elif is_ecr "$registry"; then
    echo "Logging in to AWS ECR..."
    aws ecr get-login-password | docker login --username AWS --password-stdin "$registry"
  else
    echo "Logging in to $registry..."
    echo "$token" | docker login "$registry" -u "$username" --password-stdin
  fi
}

# Check if image exists in registry
registry_image_exists() {
  local image=$1
  
  # Try to pull manifest without downloading image
  docker manifest inspect "$image" &> /dev/null
}

# Get image digest from registry
get_image_digest() {
  local image=$1
  docker inspect --format='{{index .RepoDigests 0}}' "$image" 2>/dev/null || echo ""
}

# List tags for an image in registry (GHCR specific)
list_image_tags_ghcr() {
  local username=$1
  local namespace=$2
  local token=$3
  
  curl -H "Authorization: Bearer $token" \
       "https://ghcr.io/v2/${username}/${namespace}/tags/list" 2>/dev/null | \
       jq -r '.tags[]' 2>/dev/null || echo ""
}

# Delete image from registry (GHCR specific)
delete_image_ghcr() {
  local username=$1
  local namespace=$2
  local tag=$3
  local token=$4
  
  echo "Deleting ${username}/${namespace}:${tag} from GHCR..."
  
  # Get image digest
  local digest=$(curl -H "Authorization: Bearer $token" \
                      -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
                      "https://ghcr.io/v2/${username}/${namespace}/manifests/${tag}" 2>/dev/null | \
                 jq -r '.config.digest' 2>/dev/null)
  
  if [[ -n "$digest" ]] && [[ "$digest" != "null" ]]; then
    curl -X DELETE \
         -H "Authorization: Bearer $token" \
         "https://ghcr.io/v2/${username}/${namespace}/manifests/${digest}"
  fi
}

# Validate registry credentials
validate_registry_credentials() {
  local registry=$1
  local username=$2
  local token=$3
  
  if [[ -z "$username" ]]; then
    echo "Error: Registry username not provided"
    return 1
  fi
  
  if [[ -z "$token" ]]; then
    echo "Error: Registry token not provided"
    return 1
  fi
  
  return 0
}

# Export functions
export -f get_registry
export -f get_registry_username
export -f get_registry_token
export -f build_image_name
export -f parse_image_name
export -f is_ghcr
export -f is_dockerhub
export -f is_ecr
export -f registry_login
export -f registry_image_exists
export -f get_image_digest
export -f list_image_tags_ghcr
export -f delete_image_ghcr
export -f validate_registry_credentials
