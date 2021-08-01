#!/usr/bin/env bash

source skeleton.sh

function main() {
  flag "s" "silent" "silences bubu"
  flag "w" "write to file"
  param "n" "string" "name"
  flag "show-version" "shows the version"
  description "(-> foo)"

  execute() {
    echo "Hello from foo"
  }

  help() {
    echo "Moini"
  }
}




