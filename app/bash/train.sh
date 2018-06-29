#!/usr/bin/env bash

# Script to parse uncompressed facebook archive and train conversational AI via messages data for batch of users.
# Copyright (C) 2018 Logan Martel - All Rights Reserved
# Permission to copy and modify is granted under the Apache License 2.0
# Last revised 06/29/2018
# See README.md for further details.

# To skip environment setup prompts, can hardcode valid paths here
# CONFIG_PATH="<valid_config_path>"
# LIB_PATH="<valid_config_path>"

# default environment for env_setup.sh
WORKING_DIRECTORY="$(pwd)"
DEFAULT_CONFIG_PATH="${WORKING_DIRECTORY}/config/training/training.config"
DEFAULT_CONFIG_PROMPT="Please enter path to training config file: [default = ${DEFAULT_CONFIG_PATH}]:"

# attempt to execute standard environment setup
SCRIPT_EXECUTION_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_EXECUTION_DIRECTORY/env_setup.sh;

# validate successful environment setup
if [[ ! $? = 0 ]]; then
    printf "\n";
    echo "Failed to setup environment. Exiting train.sh execution...";
    printf "\n";
    exit 1;
fi

# train.sh help message
scriptname=$(basename "$0");
help_message="\
Usage: ./$scriptname [-h] [-f] [-s]

Parse uncompressed facebook archive and train conversational AI via messages data for batch of users.

Options:

  -h, --help               Show this help information.

  -f, --force              Set FORCE_CONFIRM environment variable to force 
                           confirm all prompts (as possible).

  -s, --stats              Infer trainable sentence_lengths_array from message stats
";

# train.sh args parser
function training_args_parser() {
    if [ -z $1 ]
    then
        return 0;
    fi
    case $1 in 
        "-h"|"--help") standard_input_helpers.usage "$help_message";;  
        "-f"|"--force") FORCE_CONFIRM="y";;
        "-s"|"--stats") USE_MESSAGE_STATS="y";;
        *)
        echo "Unexpected parameter = '$1'."
        standard_input_helpers.usage "$help_message";
    esac
}

# retrieve user input arguments via custom parser
standard_input_helpers.read_all_args_via_custom_parser training_args_parser $*;

# get environment variables from config file
APPLICATION_PATH="$(standard_input_helpers.config_get APPLICATION_PATH)";
PYTHON2_PATH="$(standard_input_helpers.config_get PYTHON2_PATH)";
PYTHON3_PATH="$(standard_input_helpers.config_get PYTHON3_PATH)";
FBCAP_PATH="$(standard_input_helpers.config_get FBCAP_PATH)";
FACEBOOK_ARCHIVE_PATH="$(standard_input_helpers.config_get FACEBOOK_ARCHIVE_PATH)";
FACEBOOK_STRUCTURED_OUTPUT_TYPE="$(standard_input_helpers.config_get FACEBOOK_STRUCTURED_OUTPUT_TYPE)";
FACEBOOK_STRUCTURED_OUTFILE_PATH="$(standard_input_helpers.config_get FACEBOOK_STRUCTURED_OUTFILE_PATH)";
PARSED_DATA_FORMAT="$(standard_input_helpers.config_get PARSED_DATA_FORMAT)";
PARSED_DATA_PATH="$(standard_input_helpers.config_get PARSED_DATA_PATH)";
TRAINED_MODELS_BACKUP_PATH="$(standard_input_helpers.config_get TRAINED_MODELS_BACKUP_PATH)";
MESSAGE_STATS_DIR_PATH="$(standard_input_helpers.config_get MESSAGE_STATS_DIR_PATH)";
MESSAGE_STATS_FILE_PATH="$MESSAGE_STATS_DIR_PATH/fb_message_stats.csv";

# array variables construction
declare -a target_user_raw_strings="$(standard_input_helpers.config_get TARGET_USER_RAW_STRINGS_ARRAY)";
declare -a DEFAULT_SENTENCE_LENGTHS_ARRAY="$(standard_input_helpers.config_get DEFAULT_SENTENCE_LENGTHS_ARRAY)";
for target_user_raw_string in "${target_user_raw_strings[@]}"
do
    formatted_target_user_str="$(echo "$target_user_raw_string" | tr '[:upper:]' '[:lower:]')"
    formatted_target_user_str="$(echo ${formatted_target_user_str// /_})"
    indirect_ref_to_target_user_sentence_lengths=sentence_lengths_${formatted_target_user_str}
    eval "declare -a ${indirect_ref_to_target_user_sentence_lengths}"
    eval "${indirect_ref_to_target_user_sentence_lengths}=$(standard_input_helpers.config_get ${indirect_ref_to_target_user_sentence_lengths})"
done

# PARSE UNSTRUCTURED FACEBOOK ARCHIVE DATA TO INTENDED STRUCTURE FORMAT

if [ ! -f "$FACEBOOK_STRUCTURED_OUTFILE_PATH" ]; then
    if [ ! -d "$FACEBOOK_ARCHIVE_PATH" ]; then
        printf "\nFailed to locate facebook data archive.\n"
        printf "\nConfig path used = '$FACEBOOK_ARCHIVE_PATH'\n"
        printf "\nPlease provide valid path to 'FACEBOOK_ARCHIVE_PATH' parameter in training config\n\n"
        exit 1
    fi
    FACEBOOK_STRUCTURED_OUTFILE_DIR_PATH=$(dirname "${FACEBOOK_STRUCTURED_OUTFILE_PATH}")
    mkdir -p $FACEBOOK_STRUCTURED_OUTFILE_DIR_PATH
    $FBCAP_PATH "$FACEBOOK_ARCHIVE_PATH"/html/messages.htm -f "$FACEBOOK_STRUCTURED_OUTPUT_TYPE" > "$FACEBOOK_STRUCTURED_OUTFILE_PATH" --resolve
fi

if [ ! -s "$FACEBOOK_STRUCTURED_OUTFILE_PATH" ]; then
    echo "Something went wrong with structured facebook data creation. No valid file found at path = '$FACEBOOK_STRUCTURED_OUTFILE_PATH'"
    exit 1
fi

if [ ! -z "$USE_MESSAGE_STATS" ] || [ -z "$DEFAULT_SENTENCE_LENGTHS_ARRAY" ] || [ "$DEFAULT_SENTENCE_LENGTHS_ARRAY" == "__UNDEFINED__" ]; then
    # the user might want to infer sentence lengths from message stats
    if [ -z "$USE_MESSAGE_STATS" ]; then
        # prompt for confirmation since they are not explicitly directing us to use stats inferrence
        standard_input_helpers.prompt_confirmation "No training sentence lengths provided. Would you like to infer these from message stats (y/n)? " $FORCE_CONFIRM
        if [[ $CONFIRMATION =~ ^[Yy]$ ]]; then
            # flag the user's confirmation to infer sentence lengths from message stats
            USE_MESSAGE_STATS="y"
        fi
        CONFIRMATION="n"
    fi
    # after the user has been given the chance to confirm message stats inferrence, check the state of this variable
    if [ ! -z "$USE_MESSAGE_STATS" ]; then
        # in this case, we will infer trainable sentence lengths directly from facebook message stats
        if [ ! -s "$MESSAGE_STATS_FILE_PATH" ]; then
            # is there already a valid message stats csv
            standard_input_helpers.prompt_confirmation "No valid fb_message_stats csv found. Would you like to generate one from message data (y/n)? " $FORCE_CONFIRM
        else
            # should we append to the existing message stats csv
            standard_input_helpers.prompt_confirmation "Message stats csv found. Append to this (y/n)? " $FORCE_CONFIRM
        fi
        if [[ $CONFIRMATION =~ ^[Yy]$ ]]; then
            # temporarily reset config environment to run stats aggregation
            CACHED_CONFIG_PATH="$CONFIG_PATH"
            CONFIG_PATH=""
            # export existing lib path to subscript environment
            export LIB_PATH="$LIB_PATH"
            # execute the stats aggregation bash script
            bash $SCRIPT_EXECUTION_DIRECTORY/stats.sh
            # resume cached config environment
            CONFIG_PATH="$CACHED_CONFIG_PATH"
            # is the file ready for use
            if [ ! -s "$MESSAGE_STATS_FILE_PATH" ]; then
                echo "Something went wrong with facebook message stats aggregation. No valid file found at path = '$MESSAGE_STATS_FILE_PATH'"
                exit 1
            fi
        fi
        CONFIRMATION="n"
        # attempt to use the facebook message stats to infer trainable sentence lengths for each target user
        # fb_message_stats.csv must be formatted with columns: ['Target_User_Name', 'Total_Messages_Sent', 'Average_Words_Per_Message',
        # 'Median_Words_Per_Message', 'Max_Words_Per_Message','Min_Words_Per_Message', 'Total_Conversations_Count',
        # 'Trainable_Sentence_Length_Lower_Percentile_Value', 'Trainable_Sentence_Length_Upper_Percentile_Value']
        for target_user_raw_string in "${target_user_raw_strings[@]}"
        do
            # select row for the target user (should be unique)
            messages_stats_csv_row_select_statement="awk -F , '\$1 == \"$target_user_raw_string\" { print }' $MESSAGE_STATS_FILE_PATH"
            message_stats_csv_row_for_target_user="$(eval "${messages_stats_csv_row_select_statement}")"
            # extract average words per message from 3rd column of fb_message_stats.csv
            trainable_sentence_length_avg_words_per_message=$(echo "${message_stats_csv_row_for_target_user}" | cut -d ',' -f3)
            # extract lower words per message percentile value from 8th column of fb_message_stats.csv
            trainable_sentence_length_lower=$(echo "${message_stats_csv_row_for_target_user}" | cut -d ',' -f8)
            # extract upper words per message percentile value from 9th column of fb_message_stats.csv
            trainable_sentence_length_upper=$(echo "${message_stats_csv_row_for_target_user}" | cut -d ',' -f9)
            # format target user string for use as variable identifier
            formatted_target_user_str="$(echo "$target_user_raw_string" | tr '[:upper:]' '[:lower:]')"
            formatted_target_user_str="$(echo ${formatted_target_user_str// /_})"
            # dynamically reference target user sentence lengths array variable
            indirect_ref_to_target_user_sentence_lengths=sentence_lengths_${formatted_target_user_str}
            eval "declare -a ${indirect_ref_to_target_user_sentence_lengths}"
            # set contents of target user sentence lengths array variable according to inferred sentence lengths
            eval "${indirect_ref_to_target_user_sentence_lengths}=( ${trainable_sentence_length_lower} ${trainable_sentence_length_avg_words_per_message} ${trainable_sentence_length_upper} )"
        done
    fi
fi

# PARSE STRUCTURED FACEBOOK DATA FOR EACH USER TO REQUESTED TRAINABLE FORMAT
declare -a sentence_lengths_array=()

# helper to handle environment variables for sentence lengths
function handle_target_user_sentence_lengths() {
    sentence_lengths_array=()
    # format target user string for use as variable identifier
    formatted_target_user_str="$(echo "$target_user_raw_string" | tr '[:upper:]' '[:lower:]')"
    formatted_target_user_str="$(echo ${formatted_target_user_str// /_})"
    # dynamically reference target user sentence lengths array variable
    indirect_ref_to_target_user_sentence_lengths=sentence_lengths_${formatted_target_user_str}
    # verify that target user sentence lengths have valid contents
    eval 'target_user_sentence_lengths_contents=$'${indirect_ref_to_target_user_sentence_lengths}''
    if [ ! -z "${target_user_sentence_lengths_contents}" ] && [ ! "${target_user_sentence_lengths_contents}" == "__UNDEFINED__" ]; then
        # get number of trainable sentence lengths in target user array
        eval 'num_target_user_sentence_lengths=${#'${indirect_ref_to_target_user_sentence_lengths}'[@]}'
        # iteratively copy contents of target user sentence lengths to expected array
        for (( index=0; index<$num_target_user_sentence_lengths; index++ )); do
           get_sentence_length_cmd='echo ${'${indirect_ref_to_target_user_sentence_lengths}'['$index']}'
           sentence_length=$(eval ${get_sentence_length_cmd})
           sentence_lengths_array+=(${sentence_length})
        done
    else
        # no valid target user sentence lengths - let's try to use the defaults instead
        if [ -z "$DEFAULT_SENTENCE_LENGTHS_ARRAY" ] || [ "$DEFAULT_SENTENCE_LENGTHS_ARRAY" == "__UNDEFINED__" ]; then
            # even the default sentence lengths are unavailable - let's notify this to decide how to proceed
            printf "\n"
            standard_input_helpers.prompt_confirmation "No valid sentence lengths found for target user = '$target_user_raw_string'. Skip user and proceed (y/n)? " $FORCE_CONFIRM
            if [[ ! $CONFIRMATION =~ ^[Yy]$ ]]; then
                # this was not okay...so let's just kill execution here
                printf "\nExiting execution...\n\n"
                exit 1
            else
                # this was acceptable...so we'll just skip this user
                CONFIRMATION="n"
                continue
            fi
        else
            # we'll assign the default sentence lengths to out expected array
            sentence_lengths_array=("${DEFAULT_SENTENCE_LENGTHS_ARRAY[@]}")
        fi
    fi
}

# ensure existing directory for parsed data
mkdir -p $PARSED_DATA_PATH

# parse the messages data to trainable conversations per <user, sentence length> combo
for target_user_raw_string in "${target_user_raw_strings[@]}"
do
    handle_target_user_sentence_lengths;
    for sentence_length in "${sentence_lengths_array[@]}"
    do
        "$PYTHON2_PATH" $APPLICATION_PATH/python/fb_messages_parser.py parse_to_"$PARSED_DATA_FORMAT" -u "$target_user_raw_string" \
        -i "$FACEBOOK_STRUCTURED_OUTFILE_PATH" -o "$PARSED_DATA_PATH" -l "$sentence_length";
		if [[ ! $? = 0 ]]; then
            printf "\n"
			standard_input_helpers.prompt_confirmation "Failed to parse data for target user = '$target_user_raw_string'. Proceed anyway (y/n)? " $FORCE_CONFIRM
			if [[ ! $CONFIRMATION =~ ^[Yy]$ ]]; then
				printf "\nExiting execution...\n\n"
				exit 1
			fi
			CONFIRMATION="n"
		fi
    done
done

printf "\n"

echo "Successfully parsed trainable data for all desired users"

# TRAIN CONVERSATIONAL AI's VIA PARSED CONVERSATION DATA

train_user_bots() {
    if [[ ! -z $TRAINED_MODELS_BACKUP_PATH ]]; then
        mkdir -p $TRAINED_MODELS_BACKUP_PATH
    fi
    MODEL_TRAINING_ROOT_DIR="$(standard_input_helpers.config_get MODEL_TRAINING_ROOT_DIR)"
    TRAINABLE_MODEL_TAG_STR="$(standard_input_helpers.config_get TRAINABLE_MODEL_TAG)"
    TRAINED_MODEL_ORIGINAL_DESTINATION="$(standard_input_helpers.config_get TRAINED_MODEL_ORIGINAL_DESTINATION)"
    MODEL_TRAINING_EXECUTION_COMMAND="$(standard_input_helpers.config_get MODEL_TRAINING_EXECUTION_COMMAND)"
    for target_user_raw_string in "${target_user_raw_strings[@]}"
    do
        handle_target_user_sentence_lengths
        for sentence_length in "${sentence_lengths_array[@]}"
        do
            formatted_target_user_str="$(echo "$target_user_raw_string" | tr '[:upper:]' '[:lower:]')"
            formatted_target_user_str="$(echo ${formatted_target_user_str// /_})"
            TRAINABLE_MODEL_TAG="$(eval "echo ${TRAINABLE_MODEL_TAG_STR}")"
            eval "${MODEL_TRAINING_EXECUTION_COMMAND}"
            if [[ ! -z $TRAINED_MODELS_BACKUP_PATH ]]; then
                cur_trained_model_destination="$(eval "echo ${TRAINED_MODEL_ORIGINAL_DESTINATION}")"
                cp -R $cur_trained_model_destination $TRAINED_MODELS_BACKUP_PATH/
            fi
        done
    done
}

standard_input_helpers.prompt_confirmation "Proceed to train bots for all target users (y/n)? " $FORCE_CONFIRM
if [[ $CONFIRMATION =~ ^[Yy]$ ]]; then
    train_user_bots
fi
CONFIRMATION="n"
