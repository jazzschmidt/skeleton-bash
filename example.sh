#!/usr/bin/env bash

#
# Recursive function parsing is impossible!
# TODO: Flatten function parsing
#

{
  # Public
  declare flag_help

  declare app_name="${app_name:-$(basename "$0")}"
  declare app_version="${app_version:-"0.1.0"}"
  declare app_description="${app_description:-"My skeleton.sh app"}"

  # Internal
  declare __argv="$*" __command __command_name
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
}

function is_true() {
  local arg
  local true_values=("yes" "y" "1" "true")

  for arg in "${true_values[@]}"; do
    [ "$1" = "$arg" ] && return 0
  done

  return 1
}

source _array.sh
source _options.sh
source _commands.sh

flag "h" "Shows this help message"; flag_help="$flag"
readonly flag_help

function @foo() {
  echo "-- foo"
  flag "s" "silent" "silences bubu"
  flag "w" "write to file"
  arg "n" "string" "name"
  flag "show-version" "shows the version"
  arg "q" "quiet" "value" "quiet bubu"
  description "(-> foo)"

  execute() {
    echo "Hello from foo"
  }

  help() {
    echo "Moini"
  }
}

function @foobar() {
  command "foo bar"
  echo "-- foobar"
  flag "g" "gggg"
  args "from" "for"
  description "(-> foo bar)"

  execute() {
    echo "Goodbye $1 - $2!"
  }
}

function @test() {
  echo "-- test"
  description "(-> test)"
}

function @bar() {
  echo "-- bar"
  description "(-> bar)"

  local name="default"

  execute() {
    echo "Hello ${name}"
  }
}

main() {
  help() {
    echo "Hallo welt"
  }

  execute() {
    echo "yo"
  }
}

echo "cmd: $__command ($__command_name)"

__parse_commands

__execute_command_function "$__command" "${__opts[*]}"
