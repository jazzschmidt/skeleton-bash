#!/usr/bin/env bash

{
  # Public variables
  # ----------------
  declare flag # determines whether a flag is present
  declare -a arg # holds the values of an argument

  declare app_name="${app_name:-$(basename "$0")}"
  declare app_version="${app_version:-"0.1.0"}"
  declare app_description="${app_description:-"My shkeleton.sh app"}"

  declare flag_help=false
}

{
  # Internal variables
  # ------------------

  # current handler properties
  declare __handler_description __handler_command __parent_handler
  declare -a __handler_args=()

  # handlers
  declare -a __handlers=()

  # lists of [command]: [handler-function/description]
  declare -A __commands=()
  declare -A __commands_descriptions=()

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
  }


  # lists of [command]: [args/flags]
  declare -A __args=()
  declare -A __flags=()

  # holds the value for current parsed arg
  declare __current_arg
}


function __main() {
  local func; local -a args

  flag "h" "help" "shows help"; flag_help=$flag

  echo "command: $__command"
  local -a nested_cmd=()

  parse_handler

  for cmd in $__command; do
    nested_cmd+=("$cmd")
    parse_handler "${nested_cmd[*]}"
  done

  parse_options

  echo "Commands: ${__commands[*]}"
  echo "Handlers: ${__handlers[*]}"

  if $flag_help; then
    __help "$__command" && exit 0
  fi

  if [ -z "$__command" ] || [ ! "${__commands[$__command]+abc}" ]; then
    read -a args <<< "${__command}"
    args+=("${__handler_args[@]}")

    if >/dev/null declare -F main; then
      # Execute main with all arguments provided
      func=main
      $func "${args[@]}"
    else
      [ -n "${args[*]}" ] && echo "ERR ! Unrecognized command: ${args[*]}"
      # Run help task
      __help && exit 1
    fi
  else
    # Execute the handler function
    handler="${__commands["$__command"]}"
    $handler && execute "${__handler_args[@]}"
  fi
}

function __help() {
  local command="$1" description global_help=false usage

  # Empty help function as default
  function help() {
    echo "${__commands_descriptions[$command]}"
  }

  [ -z "$command" ] || [ "$command" = "_" ] && global_help=true

  if $global_help; then
    usage="${app_name}"
    description="${app_description}"
  else
    handler="${__commands["$command"]}" && $handler 1>&2 >/dev/null
    usage="${app_name} ${command}"
    description=$(help)
  fi

    cat <<-HELP
${description}

Usage:
  ${usage} [command] [flags]

HELP

  __print_commands "$command"

  if ! $global_help; then
    __print_options "Flags" "${command}"
    __print_options "Global flags"
  else
    __print_options "Flags"
  fi
}


# Prints all commands, alphabetically sorted
function __print_commands() {
  local command="$1"
  local intend=0 out name desc;
  local parent=""

  local -a cmds=()

  for cmd in "${!__commands[@]}"; do
    if [ "$cmd" = "$command" ]; then
      continue
    fi

    if [ "${cmd:0:${#command}}" = "$command" ]; then
      parent="${cmd:0:${#command}}"
      cmd=${cmd#$command}
      cmds+=( "$cmd" )
      continue
    fi

    if [ "$command" = "_" ] && [ "$cmd" = "${cmd/ //}" ]; then
      cmds+=( "$cmd" )
    fi
  done

  for cmd in "${cmds[@]}"; do
      name=$(echo "$cmd" | cut -d'#' -f1)
      if [ ${#name} -gt "$intend" ]; then intend=${#name}; fi;
  done

  echo "Available commands:"
  out=""
  for cmd in "${cmds[@]}"; do
      desc="${__commands_descriptions[${parent}${cmd}]}"
      out+=$(printf "  %-${intend}s   %s" "$cmd" "$desc")
      out+="\n"
  done
  echo -en "${out}" | sort -d
  echo ""
}

# Prints all options (flags/args), alphabetically sorted
function __print_options() {
  local heading="$1" command="${2:-_}"
  local options=()
  local descriptions=()
  local intend=0

  local param desc short long

  local is_args=true
  local arg;

  local -a args=()
  mapfile -t args < <(echo -e "${__args[$command]}\n###\n${__flags[$command]}")

  for arg in "${args[@]}"; do
    if [ "$arg" = "###" ]; then
      is_args=false
      continue
    fi

    short=$(echo "$arg" | cut -d'#' -f1)
    long=$(echo "$arg" | cut -d'#' -f2)

    if $is_args; then
      param=$(echo "$arg" | cut -d'#' -f3)
      desc=$(echo "$arg" | cut -d'#' -f4-)
    else
      desc=$(echo "$arg" | cut -d'#' -f3-)
    fi

    # Remove dash (-)
    short="${short%-}"; long="${long%-}"

    local line=""

    if [ -n "$short" ] && [ -n "$long" ]; then line="-$short, --$long"; fi;
    if [ -n "$short" ] && [ -z "$long" ]; then line="-$short"; fi;
    if [ -z "$short" ] && [ -n "$long" ]; then line="--$long"; fi;
    if $is_args; then line+=" ${param}"; fi;

    options+=("$line")
    descriptions+=("$desc")
    if [ ${#line} -gt "$intend" ]; then intend=${#line}; fi;
  done

  local out=""; local i=0
  local option;

  if [ "${#options[@]}" -gt 0 ]; then
    echo "${heading}"
    for option in "${options[@]}"; do
      out+=$(printf "  %-${intend}s   %s" "$option" "${descriptions[$i]}")
      out+="\n"
      (( i+=1 ))
    done
    echo -en "${out}" | sort -d
    echo ""
  fi
}




function description() {
  __handler_description="$*"
}

function command() {
  __handler_command="$*"
  [ -n "$__parent_handler" ] && __handler_command="${__parent_handler} $*"
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
  local short long param desc i value;
  local registered_args="${__args["${__handler_command:-_}"]}"
  local args=( "$@" )

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

  if [ -n "${registered_args}" ]; then registered_args+="\n"; fi
  registered_args+="${short:--}#${long:--}#${param}#${desc}"

  # Global args are saved in _
  __args+=( ["${__handler_command:-"_"}"]="${registered_args}")
  get_arg "$short" "$long"
}



# Retrieves an argument and sets $arg to its values
function get_arg() {
  local short="${1}" long="${2}"
  local match=false success=false

  arg=() # reset current value

  for opt in "${__opts[@]}"; do
    if $match; then
      arg+=("$opt")
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


# Registers a flag and sets $flag to either true or false
# ARGS:
#   $1: option (short or long)
#   $2: description
#   -- OR --
#   $1-$2: option (short and long)
#   $3: description
function flag() {
  local short long desc
  local registered_flags="${__flags["${__handler_command:-_}"]}"

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

  if [ -n "${registered_flags}" ]; then registered_flags+="\n"; fi
  registered_flags+="${short:--}#${long:--}#${desc}"

  # Global flags are saved in _
  __flags+=( ["${__handler_command:-"_"}"]="${registered_flags}" )
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








function parse_handler() {
  local command="${1%% *}" next_commands="${1#* }" handler

  echo "handler: ${__handlers[*]}"

  # Read handlers
  local -a new_handlers=()
  for handler in $(declare -F | grep '@' | cut -d'@' -f2); do
    if ! array_contains "$handler" "${__handlers[@]}"; then
      echo "appending $handler to (${new_handlers[*]})"
      new_handlers+=("$handler")
    fi
  done

  __handlers=("${new_handlers[@]}")

  echo "new handler: ${__handlers[*]}"

  for handler in "${__handlers[@]}"; do
    __handler_command="${handler}"
    __handler_description=""

    ${handler/#/@} # evaluate handler function

    # fail if a handler has no description
    [ -z "${__handler_description}" ] && echo "ERR ! No description for ${handler}!" && exit 1

    __commands+=( ["${__handler_command}"]="@${handler}" )
    __commands_descriptions+=( ["${__handler_command}"]="${__handler_description}" )
  done

  if [ -n "$command" ]; then
    handler="${__commands[$next_commands]}"
    echo "next: $next_commands handler: $handler"
    $handler
  fi

}


function array_contains() {
  local e match="$1"
  local -a args=()
  shift
  args=("$@")
  echo "TEST: $match is in ${args[*]} ??"
  for e in "${args[@]}"; do
    [ "$e" == "$match" ] && echo "yes" && return 0
  done
  echo "no" && return 1
}



function validate_option() {
  local option="$1" command="$2"

  local flags="${__flags["_"]}\n${__flags["$command"]}"
  local args="${__args["_"]}\n${__args["$command"]}"

  for flag in $(echo -e "${flags}" | cut -d'#' -f1-2 | tr '#' ' '); do
    if [ "$flag" = "-" ]; then # skip empty flags
      continue
    elif [ "$flag" = "$option" ]; then # return when present
      return
    fi
  done

  for arg in $(echo -e "${args}" | cut -d'#' -f1-2 | tr '#' ' '); do
    if [ "$arg" = "-" ]; then # skip empty args
      continue
    elif [ "$arg" = "$option" ]; then # return when present
      __current_arg="$option"
      return
    fi
  done

  echo "ERR ! Unknown option: $1" && exit 1
}

function parse_options() {
  declare opt_nr=0

  for opt in "${__opts[@]}"; do
    if [ -n "$__current_arg" ]; then
      if [ "${opt:0:1}" = "-" ]; then # value must not start with dash!
        echo "ERR ! value for $__current_arg must not start with '-'" && exit 1
      fi

      __current_arg="";
      continue
    fi

    if [ "${opt:0:2}" = "--" ]; then
      validate_option "${opt:2}" "$__command"
    elif [ "${opt:0:1}" = "-" ]; then # validate short options as lists
      for (( i=1; i<${#opt}; i++ )); do
        validate_option "${opt:$i:1}" "$__command"
      done
    elif echo " ${__opts[*]:$opt_nr+1}" | grep -qe " -"; then
      echo "ERR ! Unrecognized option '${opt}'" && exit 1
    else
      read -a __handler_args <<< "${__opts[*]:$opt_nr}"
      break
    fi

    (( opt_nr+=1 ))
  done

  if [ -n "$__current_arg" ]; then
    echo "ERR ! No value provided for $__current_arg!" && exit 1
  fi
}


# Execute _main if it was not explicitly called.
# The trap is afterwards overwritten in the _main function
function __init_trap() {
  if [ $? -eq 0 ]; then
    __main "${__args[@]}"
  fi
}

trap __init_trap EXIT
