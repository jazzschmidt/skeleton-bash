#!/usr/bin/env bash

declare -r col_red="0;31"
declare -r col_green="0;32"
declare -r col_orange="0;33"
declare -r col_blue="0;34"
declare -r col_yellow="1;33"

# Colorizes output
# ARGS:
#   $1: color code (see $col_red etc.)
#   $2: text to output (optional; otherwise text from stdin is read)
function colorize() {
  local color="${1-}"; local text="${2-}";

  [ -z "${color}" ] && error "missing color argument"

  color_code='\033['"$color"'m'
  no_color='\033[0m' # No Color

  printf "${color_code}"
  if [ -z "${text}" ]; then
    while IFS= read -ren1 -d'\n' in; do
      #printf "%s" "$in" # Read from stdin
      echo -en "$in"
    done
  else
    printf "%s" "$text"
  fi
  printf "${no_color}"
}


{
  # Colorize functions can be called directly or via pipe:
  # Example:
  #   $ echo "Hello world" | green
  #   $ red "an error occurred" >&2

  function red() {
    colorize $col_red "${@}"
  }
  function green() {
    colorize $col_green "${@}"
  }
  function orange() {
    colorize $col_orange "${@}"
  }
  function blue() {
    colorize $col_blue "${@}"
  }
  function yellow() {
    colorize $col_yellow "${@}"
  }
}

printf "Hallo Welt" | colorize $col_red
echo -e "g" | red
echo -e "g" | red
printf "Hallo\nWelt" | colorize $col_red
