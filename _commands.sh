#!/usr/bin/env bash

{
  # Internal variables
  declare __sourced=false
  (return 0 2> /dev/null) && __sourced=true

  # [command: function/description/options]
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

  declare __debug=false
  declare __trace=false
  (echo "${DEBUG-}" | grep -qi -E "^1|true|yes|y$") && __debug=true
  (echo "${TRACE-}" | grep -qi -E "^1|true|yes|y$") && __trace=true
  readonly __debug __trace
}




























