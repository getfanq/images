#!/usr/bin/env bash
#
# Version helper functions for parsing and validating versions

# Compare semantic versions
# Returns: 0 if v1 == v2, 1 if v1 > v2, 2 if v1 < v2
version_compare() {
  local v1=$1
  local v2=$2
  
  if [[ "$v1" == "$v2" ]]; then
    return 0
  fi
  
  local IFS=.
  local i ver1=($v1) ver2=($v2)
  
  # Fill empty positions in ver1 with zeros
  for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
    ver1[i]=0
  done
  
  for ((i=0; i<${#ver1[@]}; i++)); do
    if [[ -z ${ver2[i]} ]]; then
      ver2[i]=0
    fi
    if ((10#${ver1[i]} > 10#${ver2[i]})); then
      return 1
    fi
    if ((10#${ver1[i]} < 10#${ver2[i]})); then
      return 2
    fi
  done
  
  return 0
}

# Check if version is valid semantic version
is_valid_semver() {
  local version=$1
  if [[ "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?(-[a-zA-Z0-9]+)?$ ]]; then
    return 0
  fi
  return 1
}

# Extract major version
get_major_version() {
  local version=$1
  echo "$version" | cut -d. -f1
}

# Extract minor version
get_minor_version() {
  local version=$1
  echo "$version" | cut -d. -f2
}

# Extract patch version
get_patch_version() {
  local version=$1
  echo "$version" | cut -d. -f3 | cut -d- -f1
}

# Normalize version string (e.g., "20" -> "20.0.0")
normalize_version() {
  local version=$1
  local major minor patch
  
  IFS='.' read -r major minor patch <<< "$version"
  minor=${minor:-0}
  patch=${patch:-0}
  
  echo "${major}.${minor}.${patch}"
}

# Check if version is LTS
is_lts_version() {
  local type=$1
  local version=$2
  
  case "$type" in
    node)
      # Node.js LTS versions: 18, 20
      if [[ "$version" == "18" ]] || [[ "$version" == "20" ]]; then
        return 0
      fi
      ;;
    ubuntu)
      # Ubuntu LTS versions: 22.04, 24.04
      if [[ "$version" == "22.04" ]] || [[ "$version" == "24.04" ]]; then
        return 0
      fi
      ;;
  esac
  
  return 1
}

# Get latest version from array
get_latest_version() {
  local versions=("$@")
  local latest=""
  
  for version in "${versions[@]}"; do
    if [[ -z "$latest" ]]; then
      latest="$version"
    else
      version_compare "$version" "$latest"
      if [[ $? -eq 1 ]]; then
        latest="$version"
      fi
    fi
  done
  
  echo "$latest"
}

# Validate version exists in allowed list
validate_version() {
  local version=$1
  shift
  local allowed_versions=("$@")
  
  for allowed in "${allowed_versions[@]}"; do
    if [[ "$version" == "$allowed" ]]; then
      return 0
    fi
  done
  
  return 1
}

# Export functions
export -f version_compare
export -f is_valid_semver
export -f get_major_version
export -f get_minor_version
export -f get_patch_version
export -f normalize_version
export -f is_lts_version
export -f get_latest_version
export -f validate_version
