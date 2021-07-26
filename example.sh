#!/usr/bin/env bash

source test.sh

arg "l" "loglevel" "level" "sets the log level"
flag "d" "Enables debug mode"

function @foo() {
  echo "-- foo"
  flag "s" "silent" "silences bubu"
  flag "w" "write to file"
  arg "n" "string" "name"
  arg "q" "quiet" "value" "quiet bubu"
  description "says hello"

  execute() {
    echo "Hello from froo"
  }

  function @foobar() {
    command "bar"
    echo "-- foobar"
    flag "g" "gggg"
    description "says goodbye (foo bar)"

    execute() {
      echo "Goodbye $1 - $2!"
    }
  }

  function @test() {
    description "test function"
  }
}

function @bar() {
  echo "-- bar"
  description "says hello parameterized (bar)"

  local name="default"

  execute() {
    echo "Hello ${name}"
  }
}
