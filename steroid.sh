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
  flag "q" "quiet" "silences all messages"; q=$flag
  flag "debug" "verbose output"
  flag "p" "printer friendly output"

  arg "n" "name" "text" "sets the name to <text>" # -n, --name text - sets the name to <text>
  arg "b" "base" "base key for encryption" #        -b         base - base key for encryption
  arg "mad-hatter" "name" "name of the mad hatter" # --mad-hatter name - name of the mad hatter
  arg "g" "routine" "grant routine spec" #          -g routine      - grant routine spec
}

function teardown() {
  : # Will be executed when the script finishes
}

function version() {
  flag "short" "s" "short output"; short_output=$flag

  if $flagHelp; then
    printf "Shows the version of %s\n\n" "${app_name}"
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
  flag "help" "h" "Shows this help message or more information about a command"; flagHelp=$flag
  flag "debug" "Shows debug messages"; FLAG_DEBUG=$flag
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
  %s [command] [flags]\n\n" "$app_description" "$app_name"

    print_commands
  fi

  print_options
}

__commands_list=()
function add_cmd() {
  local name=$1; local func=$2; local description=$3
  __commands_list+=("${name}#${func}#${description}")
}

function print_commands() {
  local intend=0;
  for cmd in "${__commands_list[@]}"; do
      name=$(echo "$cmd" | cut -d'#' -f1)
      if [ ${#name} -gt "$intend" ]; then intend=${#name}; fi;
  done

  echo "Available commands:"
  out=""
  for cmd in "${__commands_list[@]}"; do
      name=$(echo "$cmd" | cut -d'#' -f1)
      desc=$(echo "$cmd" | cut -d'#' -f3)
      out+=$(printf "  %-${intend}s   %s" "$name" "$desc")
      out+="\n"
  done
  echo -en "${out}" | sort -d
  echo ""
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

  function print_options() {
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

    local_out=""; i=0
    if [ "${#options_local}" -gt 0 ]; then
      echo "Flags:"
      for option in "${options_local[@]}"; do
        local_out+=$(printf "  %-${intend_local}s   %s" "$option" "${desc_local[$i]}")
        local_out+="\n"
        (( i++ ))
      done
      echo -en "${local_out}" | sort -d
      echo ""
    fi

    global_out=""; i=0
    if [ "${#options_global}" -gt 0 ]; then
      echo "Global flags:"
      for option in "${options_global[@]}"; do
        global_out+=$(printf "  %-${intend_global}s   %s" "$option" "${desc_global[$i]}")
        global_out+="\n"
        (( i++ ))
      done
      echo -en "${global_out}" | sort -d
    fi
  }
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
