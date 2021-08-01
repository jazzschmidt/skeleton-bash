#!/usr/bin/env bash

source shkeleton.sh

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

#main() {
#  args "PARAM"
#  help() {
#    echo "Hallo welt"
#  }
#
#  execute() {
#    echo "yo $1"
#  }
#}



