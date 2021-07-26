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
}

function description() {
  __current_command_description="$1"
}

function command() {
  __current_command_name="$1"
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
  local parent="$1" commands
  local func command description

  commands=$(declare -F | grep -o '@.*')
  __commands=() # Reset commands list
  __commands_description=()

  if [ -z "$parent" ]; then # save global flags
    __set_command_options "_"
  fi

  for func in $commands; do
    if array_contains "$func" "${__configured_commands[@]}"; then
      continue
    fi

    __current_command_name=""
    __current_command_description=""

    # Execute command function to set/overwrite command name and description
    $func

    # Default command is function name without @
    command="${__current_command_name:-${func:1}}"

    # Prepend parent command
    if [ -n "$parent" ]; then command="$parent $command"; fi

    __add_command "$command" "$func" "$__current_command_description"
    __set_command_options "$command"

    __configured_commands+=("$func")
  done
}
