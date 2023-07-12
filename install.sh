#!/usr/bin/env bash

checkDependencies() {
  local dependencies=("curl" "jq")
  local missingDependencies=()

  if [[ "$(uname)" == "Linux" ]]; then
    if [[ -x "$(command -v apk)" ]]; then
      # Alpine Linux
      for dependency in "${dependencies[@]}"; do
        if ! command -v "$dependency" > /dev/null 2>&1; then
          missingDependencies+=("$dependency")
        fi
      done

      if [ ${#missingDependencies[@]} -gt 0 ]; then
        echo "Installing missing dependencies: ${missingDependencies[*]}"
        apk add --no-cache ${missingDependencies[*]}
      fi
    elif [[ -x "$(command -v apt-get)" ]]; then
      # Ubuntu, Debian
      for dependency in "${dependencies[@]}"; do
        if ! dpkg -s "$dependency" > /dev/null 2>&1; then
          missingDependencies+=("$dependency")
        fi
      done

      if [ ${#missingDependencies[@]} -gt 0 ]; then
        echo "Installing missing dependencies: ${missingDependencies[*]}"
        apt-get update
        apt-get install -y ${missingDependencies[*]}
      fi
    elif [[ -x "$(command -v yum)" ]]; then
      # CentOS, Red Hat
      for dependency in "${dependencies[@]}"; do
        if ! rpm -q "$dependency" > /dev/null 2>&1; then
          missingDependencies+=("$dependency")
        fi
      done

      if [ ${#missingDependencies[@]} -gt 0 ]; then
        echo "Installing missing dependencies: ${missingDependencies[*]}"
        yum install -y ${missingDependencies[*]}
      fi
    else
      echo "Unsupported package manager. Please install 'curl' and 'jq' manually."
      exit 1
    fi
  else
    echo "Unsupported operating system. Please install 'curl' and 'jq' manually."
    exit 1
  fi
}

checkDependencies
