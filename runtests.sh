#!/bin/bash

rm -rf test_result
mkdir -p test_result

FAILS=0
PASSES=0

for F in $(find tests -maxdepth 1 -name 'test_*.pbb' -type f -printf '%f\n'); do
    printf "%-30s" "$F"
    pb -P repo=. -E -i tests/$F > test_result/$F.out 2> test_result/$F.err
    if [ $? -ne 0 ]; then
        echo " FAIL - non-zero exit code"
        FAILS=$((FAILS + 1))
    elif [ -s test_result/$F.err ]; then
        echo " FAIL - non-empty error output"
        FAILS=$((FAILS + 1))
    elif [ "$(head -c 6 test_result/$F.out)" != "true" ]; then
        echo " FAIL - test failed"
        FAILS=$((FAILS + 1))
    else
        echo " OK"
        PASSES=$((PASSES + 1))
    fi
done

echo "Tests completed. $PASSES passed, $FAILS failed."
if [ $FAILS -ne 0 ]; then
    exit 1
fi
