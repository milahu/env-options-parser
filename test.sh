#! /usr/bin/env bash

while read argstring; do

echo
echo "argstring = $argstring"

./env-options-parser.sh "$argstring"

done < <( cat test-data.txt )
