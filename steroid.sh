#!/bin/bash

# App details
declare -r app_name=$(basename "$0")
declare -r app_version="0.1.0"
declare -r app_description="My custom app"

# Global flags
{
  flagHelp=
}

function setup() {
  add_flag "name string" "n" "assigns a name"
  add_flag "queue url" "Adds a url"
}

function teardown() {
  : # Will be executed when the script finishes
}

function version() {
  add_flag "short" "s" "short output"; short_output=$flag

  if $flagHelp; then
    printf "Shows the version of ${app_name}\n\n"
    print_usage && exit 0;
  fi

  if ! $short_output; then
    printf "%s { version %s } - %s\n" "$app_name" "$app_version" "$app_description"
  else
    echo "$app_version"
  fi
}

__setupFinished=false

#################
# Main function #
#################
function main() {
  add_cmd "version" "version" "Shows the version of ${app_name}"
  add_flag "help" "h" "Shows this help message or more information about a command"; flagHelp=$flag
  add_flag "debug" "Shows debug messages"; FLAG_DEBUG=$flag
  add_flag "g" "global mode"
  setup

  # Execute custom commands
  if is_custom_cmd "$1"; then
    __setupFinished=true
    exec_cmd "$1" "${*:2}"
  elif [ "$1" == "help" ]; then
    print_usage
  else
    echo "Unknown"
  fi
}

function print_usage() {
  local intend; local name; local description; local cmd; local flag

  if ! $__setupFinished; then
    # Print main help
    printf "\
%s

Usage:
  %s [command] [flags]

Available commands:
" "$app_description" "$app_name"

    intend=$(__longest_key "${__commands[@]}")

    for cmd in "${__commands[@]}" ; do
        name=$(echo "$cmd" | cut -d":" -f1)
        description=$(echo "$cmd" | cut -d":" -f2-)

        printf "  %-${intend}s  %s\n" "$name" "$description"
    done
    echo
  fi

  printf "Flags:\n"
  __print_flags "${__flags_func[@]}"

  printf "\nGlobal flags:\n"
  __print_flags "${__flags[@]}"
}

function __print_flags() {
  local flags=("$@"); local flag; local flags_formatted=();
  local name; local alias; local description; local intend;

  for flag in "${flags[@]}" ; do
      name=$(echo "--$flag" | cut -d":" -f1)
      alias=$(echo "$flag" | cut -d":" -f2)
      description=$(echo "$flag" | cut -d":" -f3-)

      if [ -n "$alias" ]; then
        name="-$alias, $name"
      elif [ "${#name}" -eq 3 ]; then
        name="${name:1}"
      fi
      flags_formatted+=("$name:$description")
  done

  intend=$(__longest_key "${flags_formatted[@]}")
  for flag in "${flags_formatted[@]}" ; do
    name=$(echo "$flag" | cut -d":" -f1)
    description=$(echo "$flag" | cut -d":" -f2-)
    printf "  %-${intend}s  %s\n" "$name" "$description"
  done
}

__commands=()
__commands_f=()
function add_cmd() {
  local name=$1; local func=$2; local description=$3
  __commands+=("${name}:${description}")
  __commands_f+=("${func}")
}

__flags=() # Global flags
__flags_func=() # Custom command flags
flag=""
function add_flag() {
  local name="$1"; local alias; local description; local flagSpec;

  if [ $# -eq 2 ]; then
    description="$2"
  else
    alias="$2";description="$3"
  fi

  flagSpec="${name}:${alias}:${description}"

  if $__setupFinished; then
    __flags_func+=("$flagSpec")
  else
    __flags+=("$flagSpec")
  fi

  flag=false && get_flag "$name" "$alias"
}

function get_flag() {
  local name; local value; local alias=$2; local match=false
  name=$(echo "$1" | cut -d' ' -f1)
  value=$(echo "$1 " | cut -d' ' -f2)

  if [ "${#name}" -eq 1 ]; then
    alias=$name; name="##"
  fi

  for arg in "${__args[@]}"; do
    # Found value, quit loop
    if $match; then
      flag=$arg && return 0
    fi

    if [ "$arg" == "--$name" ] || [ "$arg" == "-$alias" ]; then
      if [ -z "$value" ]; then
        flag=true && return 0
      else
        match=true
      fi
    fi
  done

  return 1
}


function is_custom_cmd() {
    local arg_name=$1; local cmd; local name
    for cmd in "${__commands[@]}" ; do
        name=$(echo "$cmd" | cut -d":" -f1)

        if [ "${arg_name}" = "${name}" ]; then
          return
        fi
    done

    false
}

function exec_cmd() {
    local arg_name=$1; local i; local name
    for (( i = 0; i < ${#__commands[@]}; i++ )); do
        name=$(echo "${__commands[$i]}" | cut -d":" -f1)

        if [ "${arg_name}" = "${name}" ]; then
          local func=${__commands_f[$i]}
          $func "${@:2}"
        fi
    done
}

function __longest_key() {
    local list=("$@"); local key; local length; local longest_key=0;
    for entry in "${list[@]}" ; do
        key=$(echo "$entry" | cut -d":" -f1)
        length=${#key}
        if [ "$length" -gt $longest_key ]; then
          longest_key=$length
        fi
    done

    echo "$longest_key"
}

trap "teardown" ABRT EXIT QUIT INT TERM

__args=( "$@" )
main "${__args[@]}"
