#!/usr/bin/env bash

# To skip environment setup prompts, can hardcode valid paths here
CONFIG_PATH=""
LIB_PATH=""

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
Usage: ./$scriptname [-h] [-f]

Parse uncompressed facebook archive and train conversational AI via messages data for batch of users.

Options:

  -h, --help               Show this help information.

  -f, --force              Set FORCE_CONFIRM environment variable to force 
                           confirm all prompts (as possible).
";

# train.sh args parser
function training_args_parser() {
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

declare -a target_user_raw_strings="$(standard_input_helpers.config_get TARGET_USER_RAW_STRINGS_ARRAY)";
declare -a sentence_lengths="$(standard_input_helpers.config_get SENTENCE_LENGTHS_ARRAY)";

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
    echo "Something went wrong with structured facebook data creation. No valid file found at path = 'FACEBOOK_STRUCTURED_OUTFILE_PATH'"
    exit 1
fi

# PARSE STRUCTURED FACEBOOK DATA FOR EACH USER TO REQUESTED TRAINABLE FORMAT

mkdir -p $PARSED_DATA_PATH

for target_user_raw_string in "${target_user_raw_strings[@]}"
do
    for sentence_length in "${sentence_lengths[@]}"
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
        for sentence_length in "${sentence_lengths[@]}"
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
