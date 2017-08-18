#!/usr/bin/env bash

# To skip environment setup prompts, can hardcode valid paths here
CONFIG_PATH=""
LIB_PATH=""

# default environment for env_setup.sh
WORKING_DIRECTORY="$(pwd)"
DEFAULT_CONFIG_PATH="${WORKING_DIRECTORY}/config/stats/stats.config"
DEFAULT_CONFIG_PROMPT="Please enter path to stats config file: [default = ${DEFAULT_CONFIG_PATH}]:"

# attempt to execute standard environment setup
SCRIPT_EXECUTION_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_EXECUTION_DIRECTORY/env_setup.sh;

# validate successful environment setup
if [[ ! $? = 0 ]]; then
    printf "\n";
    echo "Failed to setup environment. Exiting stats.sh execution...";
    printf "\n";
    exit 1;
fi

# stats.sh help message
scriptname=$(basename "$0");
help_message="\
Usage: ./$scriptname [-h] [-f]

Aggregate user message stats from structured facebook messages archive.

Options:

  -h, --help               Show this help information.

  -f, --force              Set FORCE_CONFIRM environment variable to force 
                           confirm all prompts (as possible).
";

# stats.sh args parser
function stats_args_parser() {
    if [ -z $1 ]
    then
        return 0;
    fi
    case $1 in 
        "-h"|"--help") standard_input_helpers.usage "$help_message";;  
        "-f") FORCE_CONFIRM="y";;
        *)
        echo "Unexpected parameter = '$1'."
        standard_input_helpers.usage "$help_message";
    esac
}

# retrieve user input arguments via custom parser
standard_input_helpers.read_all_args_via_custom_parser stats_args_parser $*;

# get environment variables from config file
APPLICATION_PATH="$(standard_input_helpers.config_get APPLICATION_PATH)";
PYTHON2_PATH="$(standard_input_helpers.config_get PYTHON2_PATH)";
PYTHON3_PATH="$(standard_input_helpers.config_get PYTHON3_PATH)";
FACEBOOK_STRUCTURED_DATA_PATH="$(standard_input_helpers.config_get FACEBOOK_STRUCTURED_DATA_PATH)";
FACEBOOK_DATA_STATS_OUTPUT_PATH="$(standard_input_helpers.config_get FACEBOOK_DATA_STATS_OUTPUT_PATH)";

declare -a target_user_raw_strings="$(standard_input_helpers.config_get TARGET_USER_RAW_STRINGS_ARRAY)";

# AGGREGATE STATS FOR ALL TARGET USERS

if [ ! -s "$FACEBOOK_STRUCTURED_DATA_PATH" ]; then
    echo "Something went wrong seeking structured facebook data. No valid file found at path = '$FACEBOOK_STRUCTURED_DATA_PATH'"
    exit 1
fi

mkdir -p $FACEBOOK_DATA_STATS_OUTPUT_PATH

for target_user_raw_string in "${target_user_raw_strings[@]}"
do
    "$PYTHON2_PATH" $APPLICATION_PATH/python/fb_messages_aggregator.py aggregate_stats_for_target_usr -u "$target_user_raw_string" \
    -i "$FACEBOOK_STRUCTURED_DATA_PATH" -o "$FACEBOOK_DATA_STATS_OUTPUT_PATH";
    if [[ ! $? = 0 ]]; then
        printf "\n"
        standard_input_helpers.prompt_confirmation "Failed to aggregate stats for target user = '$target_user_raw_string'. Proceed anyway (y/n)? " $FORCE_CONFIRM
        if [[ ! $CONFIRMATION =~ ^[Yy]$ ]]; then
            printf "\nExiting execution...\n\n"
            exit 1
        fi
        CONFIRMATION="n"
    fi
done

printf "\n"

echo "Successfully aggregated conversation stats for all desired users"
