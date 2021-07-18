#!/usr/bin/env bash

# ===========================
# ==   SHKELETON EXAMPLE   ==
# ===========================
#
# Running this example script with '$ ./example.sh hello' will greet the current user.
# When invoking '$ ./script greet --name "John Doe"', the greeting is generated as
# "Hello John Doe, nice to meet you!".
#
# Running without a command, will execute the `main` function defined below.
# To see the usage simply invoke it via '$ ./example.sh --help'.
#
# ATTENTION: In order to show usage/help for a command, we need to manually check for
# the `--help` flag. Also, the `print_usage` function must be called after the options
# for that command are defined - have a look the `greet` function.
#
# Running '$ ./example.sh hello --help' will display something like:
#
#     Greets the user
#
#     Flags:
#       --name string   who shall be greeted
#
#     Global flags:
#       -h, --help      shows this help message or more information about a command
#       -v, --verbose   enable verbose output

app_version="1.0.0"
app_description="Example Shkeleton Script"

. ./shkeleton.sh

flag_verbose=false

function setup() {
  # Add the verbose flag
  flag "v" "verbose" "enable verbose output"; flag_verbose=$flag
  # Add `hello` command, that executes `greet`
  cmd "hello" "greet" "emits a nice greeting"
}

function greet() {
  # Retrieve name via `$arg`
  arg "name" "string" "who shall be greeted"; name=${arg:-$(whoami)}

  if $flag_help; then
    printf "Greets the user\n\n"
    print_usage && exit 0; # Print usage and exit
  fi

  # Log output
  if $flag_verbose; then echo "Running hello command"; fi;
  # Greet
  echo "Hello ${name}, nice to meet you!" | green
}

function teardown() {
    : # Clean up temporary files etc.
}

function main() {
    # Remove this function if you want the tool to show it's usage instead
    echo "info: invoke me with '${app_name} --help'"
}
