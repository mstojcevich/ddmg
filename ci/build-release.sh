#!/bin/sh

set -eux

# Test for successful release build
dub build -b release
