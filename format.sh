#!/bin/bash

BASEDIR=$(dirname "$0")

for F in $(find "$BASEDIR" -iname '*.pbb'); do
    echo "formatting $F"
    pbfmt -i $F
done