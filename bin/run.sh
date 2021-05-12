#!/usr/bin/env bash

# Synopsis:
# Run the test runner on a solution.

# Arguments:
# $1: exercise slug
# $2: absolute path to solution folder
# $3: absolute path to output directory

# Output:
# Writes the test results to a results.json file in the passed-in output directory.
# The test results are formatted according to the specifications at https://github.com/exercism/docs/blob/main/building/tooling/test-runners/interface.md

# Example:
# ./bin/run.sh two-fer /absolute/path/to/two-fer/solution/folder/ /absolute/path/to/output/directory/

# If any required arguments is missing, print the usage and exit
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "usage: ./bin/run.sh exercise-slug /absolute/path/to/two-fer/solution/folder/ /absolute/path/to/output/directory/"
    exit 1
fi

slug="$1"
input_dir="${2%/}"
output_dir="${3%/}"
results_file="${output_dir}/results.json"

# Create the output directory if it doesn't exist
mkdir -p "${output_dir}"

echo "${slug}: testing..."

TEST="${input_dir}/${slug}.spec.wren"

# Run the tests for the provided implementation file and redirect stdout and
# stderr to capture it
# TODO: Replace 'RUN_TESTS_COMMAND' with the command to run the tests
# test_output=$(RUN_TESTS_COMMAND 2>&1)
# echo $TEST
# echo ln -sf ./vendor ${input_dir}/vendor
ln -sf ../../../vendor ${input_dir}/vendor
rm $results_file
test_output=$(wren_cli $TEST $results_file 2>&1)

status=$?
# echo "$test_output"

# Write the results.json file based on the exit code of the command that was
# just executed that tested the implementation file
if [ $status -eq 0 ]; then
    if [ -f $results_file ]; then
        # need to pretify the JSOn output
        cat ${results_file} | jq -M > .tmp
        mv .tmp $results_file
    else
        jq -n '{version: 2, status: "pass"}' > ${results_file}
    fi
elif [ -f $results_file ]; then
    cat ${results_file} | jq -M > .tmp
    mv .tmp $results_file

    index=$(cat $results_file | jq -M '[.tests[].status] | index("fail")')
    if [ "$index" != "null" ]; then
        trace=$(echo "$test_output" | sed -e '1,/STACKTRACE/ d' | sed "s%${input_dir}%.%")
        cat $results_file | jq -M ".tests[$index].message |= \"$trace\" " > .tmp
        mv .tmp $results_file
    fi

else
    # OPTIONAL: Sanitize the output
    # In some cases, the test output might be overly verbose, in which case stripping
    # the unneeded information can be very helpful to the student
    sanitized_test_output=$(printf "${test_output}" | sed "s%${input_dir}%%" )

    # OPTIONAL: Manually add colors to the output to help scanning the output for errors
    # If the test output does not contain colors to help identify failing (or passing)
    # tests, it can be helpful to manually add colors to the output
    # colorized_test_output=$(echo "${test_output}" \
    #      | GREP_COLOR='01;31' grep --color=always -E -e '^(ERROR:.*|.*failed)$|$' \
    #      | GREP_COLOR='01;32' grep --color=always -E -e '^.*passed$|$')

    jq -n --arg output "${sanitized_test_output}" '{version: 2, status: "error", output: $output}' > ${results_file}
fi

echo "${slug}: done"
