#!/usr/bin/env bash

# Helper script for bash standard input routines
# Author: Logan Martel
# Version: 1.0.0

# This script is a namespaced function library of bash standard input helpers

function standard_input_helpers.(){ # auto complete helper, second argument is a grep against the function list     
    # courtesy of https://edmondscommerce.github.io/programming/linux/ubuntu/building-bash-function-libraries.html
    if [[ '' == "$@" ]]
    then
        echo "Standard_Input_helpers_Helper Namespaced Functions List";
        cat $BASH_SOURCE | grep "^function[^(]" | awk '{j=" USAGE:"; for (i=5; i<=NF; i++) j=j" "$i; print $2" "j}';
    else
        echo "Standard_Input_helpers_Helper Functions Matching: $@";
        cat $BASH_SOURCE | grep "^function[^(]" | awk '{j=" USAGE:"; for (i=5; i<=NF; i++) j=j" "$i; print $2" "j}' | grep $@;
    fi
}

function standard_input_helpers.validate_bash_version_above_3() { # simple check to validate bash version is above 3 in local environment
    # courtesy of https://askubuntu.com/questions/916976/bash-one-liner-to-check-if-version-is
    # check if $BASH_VERSION is set at all
    [ -z $BASH_VERSION ] && return 1;

    # If it's set, check the version
    case $BASH_VERSION in 
        3.*) return 0 ;;
        4.*) return 0 ;;
        ?) return 1;; 
    esac
}

function standard_input_helpers.usage() { # prints usage information supplied as first argument
    printf "\n"
    if [ -z "$1" ]
    then
        echo "Usage $0 [-h] [-f]";
        echo "where  [-h] displays usage information";
        echo "where [-f] forces confirmation to all prompts (as possible)";
    else
        echo "$1";
    fi
    printf "\n";
    exit 1
}

function standard_input_helpers.prompt_confirmation() { # output $1 confirmation prompt and wait for (y/n) from user
    CONFIRMATION="n"
    if [ -z $2 ]
    then
        read -p "$1" CONFIRMATION;
    else
        CONFIRMATION=$2;
    fi
}

function standard_input_helpers.config_read_file() { # read value ($2) directly from config file ($1)
    # courtesy of https://unix.stackexchange.com/questions/175648/use-config-file-for-my-shell-script
    (grep -E "^${2}=" -m 1 "${1}" 2>/dev/null || echo "VAR=__UNDEFINED__") | head -n 1 | cut -d '=' -f 2-;
}

function standard_input_helpers.config_get() { # attempt to read value ($1) from config file given by environment ($CONFIG_PATH) or config.cfg.defaults in working directory
    # courtesy of https://unix.stackexchange.com/questions/175648/use-config-file-for-my-shell-script
    val="$(standard_input_helpers.config_read_file "${CONFIG_PATH}" "${1}")";
    if [ "${val}" = "__UNDEFINED__" ]; then
        val="$(standard_input_helpers.config_read_file config.cfg.defaults "${1}")";
    fi
    printf -- "%s" "${val}";
}

function standard_input_helpers.read_arg_via_custom_parser() { # reads single user_arg (+ params) according to case statement wrapped in function supplied as $1 to read_arg_via_custom_parser 
    # cache args parser
    ARGS_PARSER=$1;
    shift;

    # read arguments from custom args parser (responsible for managing ARGS_SHIFT) - wrapped in function passed as first argument
    # --- FORMAT ---
    # --- BEGIN EXAMPLE ---
    #   case $1 in 
    #       "-h"|"--help") standard_input_helpers.usage "$help_message";;
    #       "-u") USERNAME=$2 && ARGS_SHIFT=2;;   
    #       "-f") FORCE_CONFIRM="y";;
    #       "--test") echo "Executing a test run...";;
    #       *)
    #       echo "Unexpected parameter $1."
    #       standard_input_helpers.usage "$help_message";
    #   esac
    # --- END EXAMPLE ---

    # default number of arguments by which to shift via one call to ARGS_PARSER
    ARGS_SHIFT=1;
    # leverage ARGS_PARSER to read remaining user input arguments
    $ARGS_PARSER $*;
    return $ARGS_SHIFT;
}

function standard_input_helpers.read_all_args_via_custom_parser() { # reads all user_args (+ params) according to case statement wrapped in function supplied as $1 to read_all_args_via_custom_parser
    # cache args parser
    ARGS_PARSER=$1;
    shift;
    if [ $# == 0 ]
    then
        # if no options supplied, defer behaviour to parser
        $ARGS_PARSER $*
    fi
    # read user input
    while [ $# != 0 ]
    do
        standard_input_helpers.read_arg_via_custom_parser $ARGS_PARSER $*;
        NB_SHIFT=$?;
        I=1;
        while [[ $I -le $NB_SHIFT ]]
        do
            shift;
            ((I = I + 1));
        done
    done
}