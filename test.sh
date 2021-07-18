#!/bin/bash

function setup() {
  flag "b" "bing" "binary generator"
}

function teardown() {
    :
}

function main() {
  echo "args: $*"
}

. ./steroid.sh


