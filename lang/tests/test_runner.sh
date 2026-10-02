#!/bin/bash
#
# Run a list of test executables and write a test report.
#
# Usage: test_runner.sh [-o OUTPUT] [TEST...]
#
# The report is written to OUTPUT, or to stdout if -o is not given. -o must
# be the first argument. OUTPUT is only replaced once all tests have run, so
# an interrupted run never leaves a partial report.
#
# Zero tests is valid, and gives a passing report.
#
# Each TEST is an executable. It passes if it exits with status 0, and fails
# on any other status, if it is killed by a signal, or if it can't be run.
# The output (stdout and stderr) of failed tests is included in the report.
#
# Evaluating the report is left to other tools, so test results don't affect
# the exit status.
#
# Exit status: 0 if the report was generated, whether tests passed or failed.
# 2 on usage error, or if the report can't be written.

set -u

output=
if [ "${1-}" = "-o" ]; then
    if [ $# -lt 2 ]; then
        echo "usage: $(basename "$0") [-o OUTPUT] [TEST...]" >&2
        exit 2
    fi
    output=$2
    shift 2
fi

log=$(mktemp) || exit 2
partial=
trap 'rm -f "$log" ${partial:+"$partial"}' EXIT

# Redirect the report to a temporary file beside OUTPUT
if [ -n "$output" ]; then
    partial="$output.partial"
    exec > "$partial" || exit 2
fi

# Current time in microseconds
now_us() {
    local t=${EPOCHREALTIME//[!0-9]/}
    echo "$((10#$t))"
}

# Format microseconds as seconds, with millisecond precision
format_us() {
    local ms=$(($1 / 1000))
    printf '%d.%03ds' $((ms / 1000)) $((ms % 1000))
}

# Describe a non-zero exit status
describe_status() {
    local status=$1
    if [ "$status" -eq 126 ]; then
        echo "not executable"
    elif [ "$status" -eq 127 ]; then
        echo "not found"
    elif [ "$status" -gt 128 ]; then
        local sig
        sig=$(kill -l $((status - 128)) 2>/dev/null) || sig=$((status - 128))
        echo "killed by signal $sig"
    else
        echo "exit status $status"
    fi
}

total=$#
passed=0
failed=()
start_all=$(now_us)

echo "Running $total test(s)"
[ "$total" -eq 0 ] || echo

for test in "$@"; do
    start=$(now_us)
    if [ ! -e "$test" ]; then
        status=127
        echo "$test: no such file" > "$log"
    elif [ ! -x "$test" ] || [ -d "$test" ]; then
        status=126
        echo "$test: not an executable file" > "$log"
    else
        # A bare file name would be looked up in PATH, so make it a path
        case "$test" in
            */*) cmd=$test ;;
            *) cmd=./$test ;;
        esac
        # Run in a subshell with stderr discarded, so bash's own message for a
        # test killed by a signal ("Aborted") doesn't end up in the report.
        # The trailing exit keeps bash from exec'ing the test directly.
        ( "$cmd" > "$log" 2>&1 < /dev/null; exit $? ) 2>/dev/null
        status=$?
    fi
    elapsed=$(format_us $(($(now_us) - start)))

    if [ "$status" -eq 0 ]; then
        passed=$((passed + 1))
        echo "PASS  $test  ($elapsed)"
    else
        failed+=("$test")
        echo "FAIL  $test  ($elapsed, $(describe_status "$status"))"
        if [ -s "$log" ]; then
            sed 's/^/      | /' "$log"
            # Terminate a final line without newline
            [ -z "$(tail -c 1 "$log")" ] || echo
        fi
    fi
done

echo
echo "$total test(s), $passed passed, ${#failed[@]} failed" \
    "($(format_us $(($(now_us) - start_all))))"

if [ ${#failed[@]} -gt 0 ]; then
    echo
    echo "Failed tests:"
    printf '  %s\n' "${failed[@]}"
fi

if [ -n "$output" ]; then
    exec > /dev/null
    mv -f "$partial" "$output" || exit 2
    partial=
fi
exit 0
