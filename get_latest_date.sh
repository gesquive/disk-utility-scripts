#!/usr/bin/env bash

# Check required dependencies
readonly DEPENDENCIES="find xargs sort cut head"
for dependency in ${DEPENDENCIES}; do
  if ! command -v "${dependency}" > /dev/null 2>&1; then
    echo "ERROR: command '${dependency}' not found" >&2
    exit 2
  fi
done

if [ $# -ne 1 ]; then
  echo "Error: not enough arguments!"
  echo "Usage is: $0 path"
  exit 2
fi

find "$1" -type f -print0 | xargs -0 stat --format '%Y :%y %n' | sort -nr | cut -d: -f2- | head -n10
