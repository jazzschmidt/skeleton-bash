#!/usr/bin/env bash

#
# Recursive function parsing is impossible!
# TODO: Flatten function parsing
#

{
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
    # Set top command name (remove arguments)
    __command_name="${__command%% *}"
  }
}

source _array.sh
source _options.sh
source _commands.sh

arg "l" "loglevel" "level" "sets the log level"
flag "d" "Enables debug mode"

function @foo() {
  echo "-- foo"
  flag "s" "silent" "silences bubu"
  flag "w" "write to file"
  arg "n" "string" "name"
  arg "q" "quiet" "value" "quiet bubu"
  description "(-> foo)"

  execute() {
    echo "Hello from froo"
  }
}

function @foobar() {
  command "foobar"
  echo "-- foobar"
  flag "g" "gggg"
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

echo "cmd: $__command ($__command_name)"

__parse_commands

if ! array_contains "$__command_name" "${!__commands[@]}"; then
  # Execute main with args
  if declare -F main >/dev/null; then
    echo "main..."
    main $__command_name
  else
    echo "HELP" && exit 1
  fi
fi

func="${__commands[$__command_name]}"
$func
# set setup finished
# -h active? -> show help
# otherwise:
# TRACE=y ? set -x
# and:
execute

declare -p __commands
declare -p __commands_description
declare -p __commands_args
declare -p __commands_flags
