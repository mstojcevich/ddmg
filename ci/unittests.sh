#!/bin/sh

set -eux

# Run unit tests
dub test --skip-registry=standard
