#!/usr/bin/env bash

{
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

  function @foobar() {
    command "bar"
    echo "-- foobar"
    flag "g" "gggg"
    description "(-> foo bar)"

    execute() {
      echo "Goodbye $1 - $2!"
    }

    function @bla() {
      echo "-- bla"
      description "(-> bla)"
    }
  }

  function @test() {
    echo "-- test"
    description "(-> test)"
  }
}

function @bar() {
  echo "-- bar"
  description "(-> bar)"

  local name="default"

  execute() {
    echo "Hello ${name}"
  }
}

__parse_commands
declare -p __commands
declare -p __commands_description
declare -p __commands_args
declare -p __commands_flags

echo ""
echo ""
__parse_commands "foo"
declare -p __commands
declare -p __commands_description
declare -p __commands_args
declare -p __commands_flags

echo ""
echo ""
__parse_commands "foo bar"
declare -p __commands
declare -p __commands_description
declare -p __commands_args
declare -p __commands_flags
