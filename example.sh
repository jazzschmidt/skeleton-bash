#!/usr/bin/env bash

source skeleton.sh

function @greet() {
  description "Displays a greeting"
  param "name" "n" "name" "greets <name> instead of the current user"; name="$param"

  execute() {
    echo "Hello ${name:-$(whoami)}"
  }
}
