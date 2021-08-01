#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════╗
# ║        ≽ skeleton:bash - Bash Script Framework        ║
# ╚═══════════════════════════════════════════════════════╝
#
# Thanks for using this library. Feel free to support me at:
#   https://github.com/jazzschmidt/shkeleton
#

{
  # ┌──────────────────┐
  # │ Global variables │
  # └──────────────────┘

  declare flag_help # Is option -h present?
  declare flag_version # Is option --version present?

  # App details
  declare app_name="${app_name:-$(basename "$0")}"
  declare app_version="${app_version:-"0.1.0"}"
  declare app_description="${app_description:-$(
    cat <<EOF
≽ skeleton:bash app

Thanks for using skeleton:bash. You can set \$app_description to overwrite this message.
Run with \`DEBUG=true $app_name\` to show debug messages and use \`TRACE=true\` to enable tracing of your app.

For further information, filing bugs or supporting this project visit:
  https://github.com/jazzschmidt/shkeleton
EOF
  )}"

  declare flag # determines whether a flag is present
  declare -a params # holds the values of an argument

  # Color codes for `colorize`
  declare -r col_red="0;31"
  declare -r col_green="0;32"
  declare -r col_orange="0;33"
  declare -r col_blue="0;34"
  declare -r col_yellow="1;33"
}




{
  # ┌────────────────────┐
  # │ Internal variables │
  # └────────────────────┘
  declare __argv="$*" __command
  declare -a __opts
  {
    # set command by removing options
    __command="${__argv%% -*}"
    if [ "${__command:0:1}" = "-" ]; then
      __command="_"
      read -a __opts <<< "${__argv}"
    else
      read -a __opts <<< "${__argv:${#__command}}"
    fi
    __command="${__command:-_}"
  }

  declare __sourced=false
  (return 0 2> /dev/null) && __sourced=true
  readonly __sourced

  # [command: function/description/options]
  declare -A __commands=()
  declare -A __commands_description=()
  declare -A __commands_params=()
  declare -A __commands_flags=()

  # List of already configured commands
  declare -a __configured_commands=()

  # Current command description and name
  declare __current_command_description __current_command_name

  declare __current_command_has_args
  declare -a __current_command_args=()

  declare __current_command_can_execute

  declare __debug=false
  declare __trace=false
  (echo "${DEBUG-}" | grep -qi -E "^1|true|yes|y$") && __debug=true
  (echo "${TRACE-}" | grep -qi -E "^1|true|yes|y$") && __trace=true
  readonly __debug __trace


  # lists of [command]: [params/flags]
  declare -a __params=()
  declare -a __flags=()
  declare __current_param
}





# Main function
function __main() {
  # set shopts when script is not sourced
  if ! $__sourced; then
    set -o errexit
    set -o nounset
    set -o pipefail
  fi

  # always set errtrace
  set -o errtrace

  # Add the help flag
  flag "h" "help" "Shows this help message"; flag_help="$flag"
  flag "version" "Shows the version of $app_name"; flag_version="$flag"
  readonly flag_help flag_version

  if $flag_version; then
    printf "%s %s\n" "$app_name" "$app_version" && exit 0
  fi

  if declare -f teardown>/dev/null; then
    trap "teardown" ABRT QUIT ERR EXIT
  fi

  if declare -f setup>/dev/null; then
    setup
  fi

  __parse_commands
  __execute_command_function "$__command" "${__opts[*]}"
}



{
  # ┌──────────────────────────┐
  # │ Various helper functions │
  # └──────────────────────────┘

  # Shows an error message
  function error() {
    printf "%s %s: %s\n" "$app_name" "${FUNCNAME[1]}" "$*" | red >&2
  }

  # Shows a debug message
  function debug() {
    if $__debug; then
      printf "[DEBUG] %s %s: %s\n" "$app_name" "${FUNCNAME[1]}" "$*" | orange >&2
    fi
  }

  # Usage: array_contains "ELEMENT" "ARRAY"
  function array_contains() {
    local e match="$1"
    local -a args=()
    shift
    args=("$@")

    for e in "${args[@]}"; do
      [ "$e" == "$match" ] && return 0
    done
    return 1
  }

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





{
  # ┌───────────────────┐
  # │ Command functions │
  # └───────────────────┘

  function description() {
    __current_command_description="$1"
  }

  function command() {
    __current_command_name="$1"
  }

  function args() {
    __current_command_has_args=true
    __current_command_args=("$@")
  }

  function __set_command_options() {
    local command="$1"
    __commands_params+=(["$command"]=$(printf "%s\n" "${__params[@]}"))
    __commands_flags+=(["$command"]=$(printf "%s\n" "${__flags[@]}"))
    __params=()
    __flags=()
  }

  function __add_command() {
    local command="$1" function="$2" description="$3"

    # fail if a command has no description
    [ -z "$description" ] && error "No description for command $command!" && exit 1

    __commands+=(["$command"]="$function")
    __commands_description+=(["$command"]="$description")
  }

  function __parse_commands() {
    local commands
    local func command description exec_hash

    commands=$(declare -F | grep -o '@.*')

    __set_command_options "_"

    for func in $commands; do
      __current_command_name=""
      __current_command_description=""
      __current_command_has_args=false
      __current_command_args=()

      # Execute command function to set/overwrite command name and description
      $func >/dev/null

      # Default command is function name without @
      command="${__current_command_name:-${func:1}}"

      __add_command "$command" "$func" "$__current_command_description"
      __set_command_options "$command"

      __configured_commands+=("$func")
    done
  }

  function __execute_command_function() {
      local command="$1" options="$2" func current_command
      local i=0 has_args=false
      local -a argv=()
      local -a command_args=()

      read -a argv <<< "${command[@]}"

      for i in $(seq "${#argv[@]}" 0); do
        current_command="${argv[*]:0:i}"
        command_args=("${argv[@]:i}")

        if array_contains "$current_command" "${!__commands[@]}"; then
          func="${__commands[$current_command]}"
          break
        fi

        [ "$command" = "_" ] || has_args=true
      done

      if [ -z "$func" ]; then
        func="main"
        current_command="_"
        if [ "${command_args[*]}" = "_" ]; then
          command_args=() # Remove _ as argument
        fi
      fi

      __parse_options "$current_command"

      # Show help
      if ! declare -F "$func" >/dev/null; then
        [ "$command" != "_" ] && error "Command not found: $command"
        __help
        [ "$command" = "_" ] && exit 0 || exit 1
      fi

      __current_command_can_execute=false
      # Default execute function
      function execute() {
        debug "Command $func has no \`execute\` function"
        __help "$command" && exit 1
      }

      # Default help function
      function help() {
        echo "${__commands_description[$command]}"
      }

      exec_hash=$(declare -f execute | md5)

      # Execute command initializer once again
      $func

      # Is execute newly defined?
      if [ "$(declare -f execute | md5)" != "$exec_hash" ]; then
        __current_command_can_execute=true
      fi

      # When args are not set, this seems to be an unknown command
      if $has_args && ! $__current_command_has_args; then
        error "Command not found: ${command}" && exit 1
      fi

      if $flag_help; then
        __help "$current_command" && exit 0
      fi

      debug "Resolved command handler: $func"
      debug "Arguments: [${command_args[*]}], options: [${options[*]}]"

      # Enable tracing for custom execute functions
      if $__trace && $__current_command_can_execute; then set -o xtrace; fi
      execute "${command_args[@]}"
      exit $?
  }

  function __help() {
    local command="$1" description global_help=false usage
    local out_commands out_flags out_flags_global

    [ -z "$command" ] || [ "$command" = "_" ] && global_help=true

    if $global_help; then
      usage="${app_name}"
      description="${app_description}"
    else
      usage="${app_name} ${command}"
      description=$(help)
    fi

    out_commands=$(__print_commands "$command")
    out_flags=""
    out_flags_global=""

    if ! $global_help; then
      out_flags+=$(__print_options "${command}")
      out_flags_global+=$(__print_options)
    else
      out_flags+=$(__print_options)
    fi

    # Start output
    printf "%s\n\n" "$description"

    out_usage=$(
      if $__current_command_can_execute; then
        printf "  %s %s[flags]\n" "$usage" "${__current_command_args[*]:+${__current_command_args[*]} }"
      fi
      if [ -n "$out_commands" ]; then
        printf "  %s [command] [flags]\n\n" "$usage"
        printf "Available commands:\n%s\n" "$out_commands"
      fi
    )

    if [ -n "$out_usage" ]; then
      printf "Usage:\n%s\n\n" "$out_usage"
    fi

    if [ -n "$out_flags" ]; then
      printf "Flags:\n%s\n\n" "$out_flags"
    fi

    if [ -n "$out_flags_global" ]; then
      printf "Global flags:\n%s\n" "$out_flags_global"
    fi
  }


  # Prints all commands, alphabetically sorted
  function __print_commands() {
    local command="$1"
    local intend=0 out name desc;
    local parent=""

    local -a cmds=()

    # Collect direct subcommands
    for cmd in "${!__commands[@]}"; do
      if [ "$cmd" = "$command" ]; then
        continue
      fi

      if [ "${cmd:0:${#command}}" = "$command" ]; then
        parent="${cmd:0:${#command}}"
        cmd=${cmd#$command}

        # Skip deeper nested commands
        if [ "${cmd# }" != "${cmd/ /}" ]; then
          continue;
        fi

        cmds+=( "$cmd" )
        continue
      fi
    done

    for cmd in "${cmds[@]}"; do
        name=$(echo "$cmd" | cut -d'#' -f1)
        if [ ${#name} -gt "$intend" ]; then intend=${#name}; fi;
    done

    out=""
    for cmd in "${cmds[@]}"; do
        desc="${__commands_description[${parent}${cmd}]}"
        out+=$(printf "  %-${intend}s   %s" "$cmd" "$desc")
        out+="\n"
    done
    echo -en "${out}" | sort -d
    echo ""
  }

  # Prints all options (flags/params), alphabetically sorted
  function __print_options() {
    local command="${1:-_}"
    local options=()
    local descriptions=()
    local intend=0

    local param desc short long

    local is_params=true
    local param;

    local -a opts=()
    mapfile -t opts < <(echo -e "${__commands_params[$command]}\n###\n${__commands_flags[$command]}")

    for opt in "${opts[@]}"; do
      if [ -z "$opt" ]; then continue; fi # Skip empty lists

      if [ "$opt" = "###" ]; then
        is_params=false
        continue
      fi

      short=$(echo "$opt" | cut -d'#' -f1)
      long=$(echo "$opt" | cut -d'#' -f2)

      if $is_params; then
        param=$(echo "$opt" | cut -d'#' -f3)
        desc=$(echo "$opt" | cut -d'#' -f4-)
      else
        desc=$(echo "$opt" | cut -d'#' -f3-)
      fi

      # Remove dash (-)
      short="${short%-}"; long="${long%-}"

      local line=""

      if [ -n "$short" ] && [ -n "$long" ]; then line="-$short, --$long"; fi;
      if [ -n "$short" ] && [ -z "$long" ]; then line="-$short"; fi;
      if [ -z "$short" ] && [ -n "$long" ]; then line="    --$long"; fi;
      if $is_params; then line+=" ${param}"; fi;

      options+=("$line")
      descriptions+=("$desc")
      if [ ${#line} -gt "$intend" ]; then intend=${#line}; fi;
    done

    local out=""; local i=0
    local option;

    if [ "${#options[@]}" -gt 0 ]; then
      for option in "${options[@]}"; do
        out+=$(printf "  %-${intend}s   %s" "$option" "${descriptions[$i]}")
        out+="\n"
        (( i+=1 ))
      done
      echo -en "${out}" | sort -db
      echo ""
    fi
  }
}






{
  # ┌───────────────────┐
  # │ Options functions │
  # └───────────────────┘

  function flag() {
    local short long desc

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

    __flags+=("${short:--}#${long:--}#${desc}")
    has_flag "$short" "$long"
  }

  # Checks whether a flag is present and sets $flag
  function has_flag() {
    local short="${1}" long="${2}"

    flag=false

    if [ -n "$long" ] && echo " ${__opts[*]} " | grep -qe " --${long} "; then
      flag=true; return 0
    fi

    if [ -n "$short" ] && echo " ${__opts[*]}" | grep -qE " -[a-zA-Z0-9]*${short}"; then
      flag=true; return 0
    fi

    return 1
  }

  function param() {
    local short long param_value desc i value;
    local params=( "$@" )

    for i in $(seq "$#" 1); do
      value="${params[$i-1]}"

      if [ -z "$desc" ]; then
        desc="$value"
      elif [ -z "$param" ]; then
        param_value="$value"
      elif [ "${#value}" -eq 1 ]; then
        short="$value"
      else
        long="$value"
      fi
    done

    __params+=("${short:--}#${long:--}#${param_value}#${desc}")

    get_param "$short" "$long"
  }

  # Retrieves an argument and sets $arg to its values
  function get_param() {
    local short="${1}" long="${2}"
    local match=false success=false

    param=() # reset current value

    for opt in "${__opts[@]}"; do
      if $match; then
        param+=("$opt")
        success=true
        match=false
        continue
      fi

      if [ "$opt" == "--$long" ] || echo " $opt " | grep -qE " -[a-zA-Z0-9]*${short} "; then
        match=true
      fi
    done

    $success && return 0 || return 1
  }




  function __validate_option() {
    local option="$1" command="$2"
    local flags="${__commands_flags["$command"]}"
    local params="${__commands_params["$command"]}"

    if [ "$command" != "_" ]; then
      flags+="\n${__commands_flags["_"]}"
      params+="\n${__commands_params["_"]}"
    fi

    for flag in $(echo -e "${flags}" | cut -d'#' -f1-2 | tr '#' ' '); do
      if [ "$flag" = "-" ]; then # skip empty flags
        continue
      elif [ "$flag" = "$option" ]; then # return when present
        return
      fi
    done

    for param in $(echo -e "${params}" | cut -d'#' -f1-2 | tr '#' ' '); do
      if [ "$param" = "-" ]; then # skip empty args
        continue
      elif [ "$param" = "$option" ]; then # return when present
        __current_param="$option"
        return
      fi
    done

    error "Unknown option: $1" && exit 1
  }

  function __parse_options() {
    local opt_nr=0 command="$1"

    for opt in "${__opts[@]}"; do
      if [ -n "$__current_param" ]; then
        if [ "${opt:0:1}" = "-" ]; then # value must not start with dash!
          error "Value for $__current_param must not start with '-'" && exit 1
        fi

        __current_param="";
        continue
      fi

      if [ "${opt:0:2}" = "--" ]; then
        __validate_option "${opt:2}" "$command"
      elif [ "${opt:0:1}" = "-" ]; then # validate short options as lists
        for (( i=1; i<${#opt}; i++ )); do
          __validate_option "${opt:$i:1}" "$command"
        done
      else
        error "Unrecognized option '${opt}'" && exit 1
      fi

      (( opt_nr+=1 ))
    done

    if [ -n "$__current_param" ]; then
      error "No value provided for $__current_param" && exit 1
    fi
  }
}






# Execute __main if it was not explicitly called.
function __init_trap() {
  local exit_code="$?"

  if declare -f teardown>/dev/null; then
    error "Cannot use teardown function without explicit call to __main"
  fi

  if [ $exit_code -eq 0 ]; then
    __main "${__argv[@]}"
  fi
}

trap __init_trap EXIT
