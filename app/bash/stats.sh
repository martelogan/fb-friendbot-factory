#!/usr/bin/env bash

# To skip prompt, enter valid path to stats config file here
CONFIG_PATH=""

validate_bash_version_above_3() {
    # check if $BASH_VERSION is set at all
    [ -z $BASH_VERSION ] && return 1

    # If it's set, check the version
    case $BASH_VERSION in 
        3.*) return 0 ;;
        4.*) return 0 ;;
        ?) return 1;; 
    esac
}

if ! validate_bash_version_above_3; then
    echo "Scripts requires bash version >= 3"
    exit 1
fi

usage() {
    printf "\n"
    echo "Usage $0 [-h] [-f]"
    echo "where  [-h] displays usage information"
    echo "where [-f] forces confirmation to all prompts (as possible)"
    printf "\n";
    exit 1
}

read_args() {
    ARGS_SHIFT=1
    case $1 in 
        "-h") usage;;
        "-u") USERNAME=$2 && ARGS_SHIFT=2;;
        "-p") PASSWORD=$2 && ARGS_SHIFT=2;;   
        "-f") FORCE_CONFIRM="y";;
        *)
        echo "Unexpected parameter $1."
        usage;
    esac
    return $ARGS_SHIFT
}

prompt_confirmation() {
    CONFIRMATION="n"
    if [ -z $2 ]
    then
        read -p "$1" CONFIRMATION
    else
        CONFIRMATION=$2
    fi
}

config_read_file() {
    (grep -E "^${2}=" -m 1 "${1}" 2>/dev/null || echo "VAR=__UNDEFINED__") | head -n 1 | cut -d '=' -f 2-;
}

config_get() {
    val="$(config_read_file "${CONFIG_PATH}" "${1}")";
    if [ "${val}" = "__UNDEFINED__" ]; then
        val="$(config_read_file config.cfg.defaults "${1}")";
    fi
    printf -- "%s" "${val}";
}

# read user input
while [ $# != 0 ]
do
    read_args $*
    NB_SHIFT=$?
    I=1
    while [[ $I -le $NB_SHIFT ]]
    do
        shift
        ((I = I + 1))
    done
done

if [[ -z $CONFIG_PATH ]]; then
    working_directory="$(pwd)"
    if [[ -z $FORCE_CONFIRM ]]; then
        read -p "Please enter path to stats config file: [default = ${working_directory}/config/stats/stats.config]:" CONFIG_PATH
    fi
    if [[ $CONFIG_PATH = "" ]]; then
        CONFIG_PATH="${working_directory}/config/stats/stats.config"
    fi
fi

APPLICATION_PATH="$(config_get APPLICATION_PATH)";
PYTHON2_PATH="$(config_get PYTHON2_PATH)";
PYTHON3_PATH="$(config_get PYTHON3_PATH)";
FACEBOOK_STRUCTURED_DATA_PATH="$(config_get FACEBOOK_STRUCTURED_DATA_PATH)";
FACEBOOK_DATA_STATS_OUTPUT_PATH="$(config_get FACEBOOK_DATA_STATS_OUTPUT_PATH)";

declare -a target_user_raw_strings="$(config_get TARGET_USER_RAW_STRINGS_ARRAY)";

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
        prompt_confirmation "Failed to aggregate stats for target user = '$target_user_raw_string'. Proceed anyway (y/n)? " $FORCE_CONFIRM
        if [[ ! $CONFIRMATION =~ ^[Yy]$ ]]; then
            printf "\nExiting execution...\n\n"
            exit 1
        fi
        CONFIRMATION="n"
    fi
done

printf "\n"

echo "Successfully aggregated conversation stats for all desired users"
