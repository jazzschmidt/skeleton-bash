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

  # TODO:
  flag "q" "quiet" "silences all messages"; q=$flag
  flag "debug" "verbose output"
  flag "p" "printer friendly output"

  arg "n" "name" "text" "sets the name to <text>" # -n, --name text - sets the name to <text>
  arg "b" "base" "base key for encryption" #        -b         base - base key for encryption
  arg "mad-hatter" "name" "name of the mad hatter" # --mad-hatter name - name of the mad hatter
  arg "g" "routine" "grant routine spec" #          -g routine      - grant routine spec

  print_args
  exit 0
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

function error() {
    >&2 printf "%s %s: %s\n" "$app_name" "${FUNCNAME[1]}" "$*" && exit 1
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

{
  # Flags

  flag=
  __flags_list=()

  # flag "q" "qiet" "silences all messages"
  # flag "debug" "verbose output"
  # flag "p" "printer friendly output"
  # $short#$long#$description
  function flag() {
    local short; local long; local desc;

    if [ "$#" -ne 2 ] && [ "$#" -ne 3 ]; then
      error "wrong number of arguments"
    fi

    while [ $# -gt 1 ]; do
      local value="$1"
      if [ "${#value}" -eq 1 ]; then
        short="${value}"
      else
        long="${value}"
      fi
      shift
    done

    desc="$1"

    $__setupFinished && scope="local" || scope="global"

    __flags_list+=("${scope}#${short:--}#${long:--}#${desc}")

    flag=false && has_flag "$short" "$long"
  }

  function has_flag() {
    local short="${1:-#}"; local long="${2:-#}";

    for arg in "${__args[@]}"; do
      if [ "$arg" == "-$short" ] || [ "$arg" == "--$long" ]; then
        flag=true && return 0
      fi
    done

    return 1
  }
}

{
  # Args

  arg=
  __args_list=()

  # arg "n" "name" "text" "sets the name to <text>" # -n, --name text - sets the name to <text>
  # arg "b" "base" "base key for encryption" #        -b         base - base key for encryption
  # arg "mad-hatter" "name" "name of the mad hatter" # --mad-hatter name - name of the mad hatter
  # arg "g" "routine" "grant routine spec" #          -g routine      - grant routine spec
  function arg() {
    local short; local long; local param; local desc;

    if [ "$#" -ne 3 ] && [ "$#" -ne 4 ]; then
      error "wrong number of arguments"
    fi

    args=( "$@" )
    for i in $(seq "$#" 1); do
      value="${args[$i-1]}"

      if [ -z "$desc" ]; then
        desc="$value"
      elif [ -z "$param" ]; then
        param="$value"
      elif [ "${#value}" -eq 1 ]; then
        short="$value"
      else
        long="$value"
      fi
    done

    $__setupFinished && scope="local" || scope="global"

    __args_list+=("${scope}#${short:--}#${long:--}#${param}#${desc}")
    arg="" && get_arg "$short" "$long"
  }

  function get_arg() {
    local short="${1:-#}"; local long="${2:-#}"; local match=false;

    for arg_v in "${__args[@]}"; do
      if $match; then
        arg="$arg_v" && return 0
      fi

      if [ "$arg_v" == "-$short" ] || [ "$arg_v" == "--$long" ]; then
        match=true
      fi
    done

    return 1
  }

  function print_args() {
    local options_local=(); local options_global=();
    local desc_local=(); local desc_global=();
    local intend_local=0; local intend_global=0;

    local is_args=true
    for arg in "${__args_list[@]}" "###" "${__flags_list[@]}"; do
      if [ "$arg" = "###" ]; then
        is_args=false
        continue
      fi

      scope=$(echo "$arg" | cut -d'#' -f1)
      short=$(echo "$arg" | cut -d'#' -f2)
      long=$(echo "$arg" | cut -d'#' -f3)

      if $is_args; then
        param=$(echo "$arg" | cut -d'#' -f4)
        desc=$(echo "$arg" | cut -d'#' -f5-)
      else
        desc=$(echo "$arg" | cut -d'#' -f4-)
      fi

      # Remove dash (-)
      short="${short%-}"; long="${long%-}"

      line=

      if [ -n "$short" ] && [ -n "$long" ]; then line="-$short, --$long"; fi;
      if [ -n "$short" ] && [ -z "$long" ]; then line="-$short"; fi;
      if [ -z "$short" ] && [ -n "$long" ]; then line="--$long"; fi;
      if $is_args; then line+=" ${param}"; fi;

      if [ "$scope" = "local" ]; then
        options_local+=("$line")
        desc_local+=("$desc")
        if [ ${#line} -gt "$intend_local" ]; then intend_local=${#line}; fi;
      else
        options_global+=("$line")
        desc_global+=("$desc")
        if [ ${#line} -gt "$intend_global" ]; then intend_global=${#line}; fi;
      fi
    done

    global_out=""; i=0
    for option in "${options_global[@]}"; do
      global_out+=$(printf "  %-${intend_global}s   %s" "$option" "${desc_global[$i]}")
      global_out+="\n"
      (( i++ ))
    done

    echo -en "${global_out}" | sort -d
  }
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
