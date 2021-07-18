#!/usr/bin/env bash
# ========================================
# ==    BASH SCRIPT TEMPLATE   ==
# ========================================
#
# This script can be used to conveniently create simple-to-use bash script.
# Either source this script or extend it to your needs and distribute it as a whole.
#
#
# ======================
# == USAGE AS LIBRARY ==
# ======================
# When used as a library, alas being sourced from your script, you need to define the
# function `setup` in order to define options and provide startup code. Otherwise an
# error will be raised.
#
# If a `teardown` function is defined, it will be called upon exiting the script.
#
# If a `main` function is defined, it will be executed with all options provided to
# the script when invoking your script without a command. Without the main function, the
# usage of your script will be displayed.
#
# You can define flag options via the `flag` function and argument options via `arg`.
# Options added from your setup function will have global scope; options added from
# command functions are bound to that command and will be displayed differently in the
# usage.
#
# Commands can be added with `cmd`.
#
# -- EXAMPLE --
# See 'example.sh' for a simple example.
#
# Thanks for using this library. Feel free to support me at https://github.com/jazzschmidt/shkeleton
#




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


# Default command `version` shows an extended version information of your app
# Option -s/--short emits the version number only
function version() {
  flag "short" "s" "short output"; short_output=$flag

  if $flag_help; then
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
    declare -r __args=( "$@" )

    declare __sourced=false
    (return 0 2> /dev/null) && __sourced=true
    readonly __sourced

    declare __debug=false
    declare __trace=false
    (echo "${DEBUG-}" | grep -qi -E "^1|true|yes|y$") && __debug=true
    (echo "${TRACE-}" | grep -qi -E "^1|true|yes|y$") && __trace=true
    readonly __debug __trace

    declare __setupFinished=false
    declare __commands_list=()
    declare __flags_list=()
    declare __args_list=()
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

# Shows an error message
function error() {
  printf "%s %s: %s\n" "$app_name" "${FUNCNAME[1]}" "$*" | >&2 red
  exit 1
}

# Shows a debug message
function debug() {
  if $__debug; then
    printf "[DEBUG] %s %s: %s\n" "$app_name" "${FUNCNAME[1]}" "$*" | orange
  fi
}


# Colorizes output
# ARGS:
#   $1: color code (see $col_red etc.)
#   $2: text to output (optional; otherwise text from stdin is read)
function colorize() {
  local color="${1-}"; local text="${2-}";

  [ -z "${color}" ] && error "missing color argument"
  [ -z "${text}" ] && IFS= read -re text # Read from stdin

  color_code='\033['"$color"'m'
  no_color='\033[0m' # No Color
  printf "${color_code}%s${no_color}\n" "$text"
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

    __print_commands
  fi

  __print_options
}






# Registers a custom command
# ARGS:
#   $1: name of the command
#   $2: function
#   $3: command description
function cmd() {
  local name=$1; local func=$2; local description=$3
  __commands_list+=("${name}#${func}#${description}")
}

# Checks if $1 is a custom command
function __is_custom_cmd() {
  local commands
  printf -v commands "%s\n" "${__commands_list[@]}"
  echo "${commands}" | cut -d'#' -f1 | grep "^$1" >/dev/null
}




# Executes the custom command $1
function __exec_cmd() {
  local func; local commands
  printf -v commands "%s\n" "${__commands_list[@]}"
  func=$(echo "${commands}" | cut -d'#' -f1-2 | grep "^$1#" | cut -d'#' -f2)

  # Enable trace output if TRACE is set to true
  if $__trace; then set -o xtrace; fi;

  $func "${@:2}"
}



# Prints all commands, alphabetically sorted
function __print_commands() {
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







# Registers a flag and sets $flag to either true or false
# ARGS:
#   $1: option (short or long)
#   $2: description
#   -- OR --
#   $1-$2: option (short and long)
#   $3: description
function flag() {
  local short; local long; local desc; local scope;

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

# Checks whether a flag is present
function has_flag() {
  local short="${1:-#}"; local long="${2:-#}";

  for arg in "${__args[@]-}"; do
    if [ "$arg" == "-$short" ] || [ "$arg" == "--$long" ]; then
      flag=true && return 0
    fi
  done

  return 1
}








# Registers an argument and sets $arg to its value, if present.
# ARGS:
#   $1: option (short or long)
#   $2: parameter name
#   $3: description
#   -- OR --
#   $1-$2: option (short and long)
#   $3: parameter name
#   $4: description
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




# Retrieves an argument and sets $arg to its value
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



# Prints all options (flags/args), alphabetically sorted
function __print_options() {
  local options_local=(); local options_global=();
  local desc_local=(); local desc_global=();
  local intend_local=0; local intend_global=0;

  local param; local desc;
  local scope; local short; local long;

  local is_args=true
  local arg;
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

    local line=""

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
  local option;

  if [ "${#options_local[@]}" -gt 0 ]; then
    echo "Flags:"
    for option in "${options_local[@]}"; do
      local_out+=$(printf "  %-${intend_local}s   %s" "$option" "${desc_local[$i]}")
      local_out+="\n"
      (( i+=1 ))
    done
    echo -en "${local_out}" | sort -d
    echo ""
  fi

  local global_out=""; i=0

  if [ "${#options_global[@]}" -gt 0 ]; then
    echo "Global flags:"
    for option in "${options_global[@]}"; do
      global_out+=$(printf "  %-${intend_global}s   %s" "$option" "${desc_global[$i]}")
      global_out+="\n"
      (( i+=1 ))
    done
    echo -en "${global_out}" | sort -d
  fi
}







# MAIN FUNCTION
# -------------
function _main() {
  # set shopts when script is not sourced
  if ! $__sourced; then
    set -o errexit
    set -o nounset
    set -o pipefail
  fi

  # always set errtrace
  set -o errtrace

  # fail if no `setup` function is defined
  if $__sourced && ! declare -F setup >/dev/null; then
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
  _setup
  $__sourced && setup


  local command="${1:-}"
  # Execute `main` function if defined and no command is set
  if [ -z "$command" ] || [ "${command:0:1}" = "-" ] && ! $flag_help ; then
    if declare -F main >/dev/null; then
      if $__trace; then set -o xtrace; fi;
      main "${@:1}"
      exit $?
    fi
  fi

  if [ -z "$command" ]; then
    command="--help"
  fi

  debug "command: $command"

  # Execute custom commands
  if __is_custom_cmd "$command"; then
    __setupFinished=true
    __exec_cmd "$command" "${@:2}"
  elif [ "$command" == "--help" ]; then
    print_usage
  else
    >&2 printf "%s: unknown command \"%s\"\n" "$app_name" "$1"
    >&2 printf "Run '%s --help' for usage info.\n" "$app_name"
    exit 1
  fi
}

# Execute _main if it was not explicitly called.
# The trap is afterwards overwritten in the _main function
function __init_trap() {
  if [ $? -eq 0 ]; then
    _main "${__args[@]}"
  fi
}

trap __init_trap EXIT
