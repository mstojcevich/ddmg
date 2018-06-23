#!/usr/bin/env bash

find ./test-roms/mooneye-gb_hwtests/acceptance -type f -iname "*.gb" -print0 | while IFS= read -r -d $'\0' line; do
  TEST_NAME=$(grep --color=never -oE "([[:alnum:]]|_|-)+\.gb" <<< $line | rev | cut -c 4- | rev)
  echo "mooneye-$TEST_NAME:
  stage: test
  dependencies:
    - build:linux
  script: ./ddmg --rom \"$line\" --testMode \"mooneye\"
  "
done
