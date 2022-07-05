#!/bin/bash

# Check for all necessary tools
function check_tools {
  for tool in "$@"; do
    if ! command -v "$tool" &>/dev/null; then
      printf "'%s' could not be found. Aborting.\n" "$tool"
      exit
    fi
  done
}
