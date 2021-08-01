#!/usr/bin/env bash

{
  # Internal variables

  # [command: function/description]
  declare -A __commands=()
  declare -A __commands_description=()
  declare -A __commands_args=()
  declare -A __commands_flags=()

  # List of already configured commands
  declare -a __configured_commands=()

  # Current command description and name
  declare __current_command_description __current_command_name

  declare __current_command_has_args
  declare -a __current_command_args=()

  declare __current_command_can_execute

  declare __debug=true
  declare __trace=false
  (echo "${DEBUG-}" | grep -qi -E "^1|true|yes|y$") && __debug=true
  (echo "${TRACE-}" | grep -qi -E "^1|true|yes|y$") && __trace=true
  readonly __debug __trace
}

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
  __commands_args+=(["$command"]=$(printf "%s\n" "${__args[@]}"))
  __commands_flags+=(["$command"]=$(printf "%s\n" "${__flags[@]}"))
  __args=()
  __flags=()
}

function __add_command() {
  local command="$1" function="$2" description="$3"

  # fail if a command has no description
  [ -z "$description" ] && echo "ERR ! No description for $command!" && exit 1

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
      [ "$command" != "_" ] && echo "ERR ! Command not found: $command"
      __help
      [ "$command" = "_" ] && exit 0 || exit 1
    fi

    __current_command_can_execute=false
    # Default execute function
    function execute() {
      echo "ERR ! Cannot execute $func"
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

    if $has_args && ! $__current_command_has_args; then
      echo "ERR ! Command ${command} not found" && exit 1
    fi

    if $flag_help; then
      __help "$current_command" && exit 0
    fi

    debug "Resolved command handler: $func"
    debug "Arguments: [${command_args[*]}], options: [${options[*]}]"

    execute "${command_args[@]}"
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

  out=""
  for cmd in "${cmds[@]}"; do
      desc="${__commands_description[${parent}${cmd}]}"
      out+=$(printf "  %-${intend}s   %s" "$cmd" "$desc")
      out+="\n"
  done
  echo -en "${out}" | sort -d
  echo ""
}

# Prints all options (flags/args), alphabetically sorted
function __print_options() {
  local command="${1:-_}"
  local options=()
  local descriptions=()
  local intend=0

  local param desc short long

  local is_args=true
  local arg;

  local -a args=()
  mapfile -t args < <(echo -e "${__commands_args[$command]}\n###\n${__commands_flags[$command]}")

  for arg in "${args[@]}"; do
    if [ -z "$arg" ]; then continue; fi # Skip empty lists

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
    if [ -z "$short" ] && [ -n "$long" ]; then line="    --$long"; fi;
    if $is_args; then line+=" ${param}"; fi;

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


# Shows an error message
function error() {
  printf "%s %s: %s\n" "$app_name" "${FUNCNAME[1]}" "$*" >&2
  exit 1
}

# Shows a debug message
function debug() {
  if $__debug; then
    printf "[DEBUG] %s %s: %s\n" "$app_name" "${FUNCNAME[1]}" "$*" >&2
  fi
}
