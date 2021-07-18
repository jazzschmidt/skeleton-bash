#!/usr/bin/env bash

# shkeleton


# Global flags and variables
{
  # App details
  declare -r app_name=$(basename "$0")
  declare -r app_version=${app_version:-"0.1.0"}
  declare -r app_description=${app_description:-"My shkeleton app"}

  # Helper variables; used to retrieve options
  declare flag=false
  declare arg=""

  declare flag_help=false
}

function _setup() {
  : # Will be executed when script starts; before setup
}

function _teardown() {
  : # Will be executed when the script finishes; after teardown
}



function version() {
  flag "short" "s" "short output"; short_output=$flag

  if $flagHelp; then
    printf "Shows the version of %s\n\n" "${app_name}"
    print_usage && exit 0;
  fi

  if ! $short_output; then
    printf "%s { version %s }\n" "$app_name" "$app_version"
  else
    echo "$app_version"
  fi
}










{
  # Internals
  {
    __setupFinished=false
    __args=( "$@" )
    __commands_list=()
    __flags_list=()
    __args_list=()
  }

  # Colors
  {
    declare -r col_red="0;31"
    declare -r col_green="0;32"
    declare -r col_orange="0;33"
    declare -r col_blue="0;34"
    declare -r col_yellow="1;33"
  }
}

# Shows error message on stderr
function error() {
  printf "%s %s: %s\n" "$app_name" "${FUNCNAME[1]}" "$*" | >&2 colorize $col_red
  exit 1
}

# Colorizes output via pipe
function colorize() {
  local color="$1"; local text="$2";

  [ -z "$color" ] && error "missing color argument"
  [ -z "$text" ] && IFS= read -re text # Read from stdin

  color_code='\033['"$color"'m'
  no_color='\033[0m' # No Color
  printf "${color_code}%s${no_color}\n" "$text"
}

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

# Prints usage information
function print_usage() {
  local intend; local name; local description; local cmd; local flag

  if ! $__setupFinished; then
    # Print main help
    cat <<-HELP
${app_description}

Usage:
${app_name} [command] [flags]

HELP

    print_commands
  fi

  print_options
}






# Registers a custom command
function cmd() {
  local name=$1; local func=$2; local description=$3
  __commands_list+=("${name}#${func}#${description}")
}

# Checks if $1 is a custom command
function is_custom_cmd() {
  echo "${__commands_list[*]}" | cut -d'#' -f1 | grep "^$1" >/dev/null
}

# Executes the custom command $1
function exec_cmd() {
  local func
  func=$(echo "${__commands_list[*]}" | cut -d'#' -f1-2 | grep "^$1#" | cut -d'#' -f2)
  $func "${@:2}"
}

function print_commands() {
  local intend=0; local out;
  local name; local desc;

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







# Registers a flag
function flag() {
  local short; local long; local desc; local scope;

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

  flag=false && has_flag "$short" "$long" || true
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








# Args

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

  local param; local desc;
  local scope; local short; local long;

  local is_args=true
  local arg;
  for arg in "${__args_list[@]-}" "###" "${__flags_list[@]}"; do
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

    local line=

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

  local local_out=""; local i=0
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

  local global_out=""; i=0
  local option;

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







#################
# Main function #
#################
function _main() {
  # set shopts when script is not sourced
  if ! (return 0 2> /dev/null); then
    set -o errexit
    set -o nounset
    set -o pipefail
  fi

  # always set errtrace
  set -o errtrace

  # fail if no `setup` function is defined
  if ! declare -F setup >/dev/null; then
    error "no setup function defined"
  fi

  # add the default command `version` and the help flag
  cmd "version" "version" "shows the version of ${app_name}"
  flag "h" "help" "shows this help message or more information about a command"; flag_help=$flag

  # Register teardown functions
  local teardown_cmd="_teardown"
  if declare -F teardown >/dev/null; then
    teardown_cmd="teardown; _teardown"
  fi
  trap "${teardown_cmd}" ABRT EXIT QUIT ERR

  # Local setup and internal setup
  _setup && setup


  local command="$1"
  # Execute `main` function if defined and no command is set
  if [ -z "$command" ] || [ "${command:0:1}" = "-" ] ; then
    if declare -F main >/dev/null; then
      main "${@:1}"
      exit $?
    fi
  fi

  # Execute custom commands
  if is_custom_cmd "$command"; then
    __setupFinished=true
    exec_cmd "$command" "${@:2}"
  elif [ "$command" == "--help" ]; then
    print_usage
  else
    >&2 printf "%s: unknown command \"%s\"\n" "$app_name" "$1"
    >&2 printf "Run '%s --help' for usage info.\n" "$app_name"
    exit 1
  fi
}

_main "${__args[@]}"
