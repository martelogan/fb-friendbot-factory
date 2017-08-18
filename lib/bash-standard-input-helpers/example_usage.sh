#!/usr/bin/env bash

# example help message
scriptname=$(basename "$0");
help_message="\
Usage: ./$scriptname [-h] [-u <username>] [-f] [--test]

Exhibit example behaviour of standard_input_helpers library.

Options:

  -h, --help               Show this help information.

  -u, --username           Set USERNAME environment variable.

  -f, --force              Set FORCE_CONFIRM environment variable to force 
                           confirm all prompts (as possible).

  --test                   Test run the script with no other parameters.
";

function example_args_parser() {
    if [ -z $1 ]
    then
        standard_input_helpers.usage "$help_message";
    fi
    case $1 in 
        "-h"|"--help") standard_input_helpers.usage "$help_message";;
        "-u") USERNAME=$2 && ARGS_SHIFT=2;;   
        "-f") FORCE_CONFIRM="y";;
		"--test") echo "Executing a test run...";;
        *)
        echo "Unexpected parameter $1."
        standard_input_helpers.usage "$help_message";
    esac
}

# load standard_input_helpers library
source standard_input_helpers.sh;

# retrieve user input arguments via custom parser
standard_input_helpers.read_all_args_via_custom_parser example_args_parser $*;

# demonstrate if username was parsed sucessfully
printf "\n";
if [ -z $USERNAME ]
then
	echo "No username set. This is okay if we did not run $scriptname -u <USERNAME>";
	echo "Something went wrong *only* if the -u option was indeed supplied.";
else
	echo "Username set to '$USERNAME'"
fi

# demonstrate example usage of confirmation prompts
NOTICE_ABOUT_FORCE_STR="\
NOTE: if you had to be prompted to see my greeting,\n\
you could have skipped this by supplying '-f' when running\n\
$scriptname.\n\n";
WARNING_ABOUT_FORCE_STR="\
WARNING: careful about forcing through my greeting...\n\
any other prompts will be force confirmed as well\n\n";
# prompt user for confirmation (skip if force parameter was supplied)
standard_input_helpers.prompt_confirmation "Want me to say hello (y/n)? " $FORCE_CONFIRM;
# check if user answered in the affirmative
if [[ $CONFIRMATION =~ ^[Yy]$ ]]; then
	printf "\n"
	echo "Hello :)"
	printf "\n"
	if [ -z $FORCE_CONFIRM ]
	then
		printf "$NOTICE_ABOUT_FORCE_STR"
	else
		printf "$WARNING_ABOUT_FORCE_STR"
	fi
fi
# reset CONFIRMATION environment variable for next time
CONFIRMATION="n";

# demonstrate example usage of config file
if [[ -z $CONFIG_PATH ]]; then
    working_directory="$(pwd)"
    if [[ -z $FORCE_CONFIRM ]]; then
        read -p "Please enter path to config file: [default = ${working_directory}/example.config]:" CONFIG_PATH;
    fi
    if [[ $CONFIG_PATH = "" ]]; then
        CONFIG_PATH="${working_directory}/example.config";
    fi
fi

# prompt user for confirmation (skip if force parameter was supplied)
standard_input_helpers.prompt_confirmation "Want to get an example value from the config file (y/n)? " $FORCE_CONFIRM;
# check if user answered in the affirmative
if [[ $CONFIRMATION =~ ^[Yy]$ ]]; then
	EXAMPLE_VALUE="$(standard_input_helpers.config_get EXAMPLE_VALUE)";
    printf "\n";
    if [ "${EXAMPLE_VALUE}" = "__UNDEFINED__" ]; then
        echo "Unable to retrieve 'EXAMPLE_VALUE' from config file at path = '${CONFIG_PATH}' or via default 'config.cgf.defaults'";
    else
    	echo "Example value retrieved from config file = '$EXAMPLE_VALUE'";
    fi
	printf "\n";
fi
# reset CONFIRMATION environment variable for next time
CONFIRMATION="n";

# prompt user for confirmation (skip if force parameter was supplied)
standard_input_helpers.prompt_confirmation "Want to try iterating through example array from config file (y/n)? " $FORCE_CONFIRM;
# check if user answered in the affirmative
if [[ $CONFIRMATION =~ ^[Yy]$ ]]; then
	declare -a example_strings_array="$(standard_input_helpers.config_get EXAMPLE_STRINGS_ARRAY)";
	printf "\n";
    if [ "${example_strings_array}" = "__UNDEFINED__" ]; then
        echo "Unable to retrieve 'EXAMPLE_STRINGS_ARRAY' from config file at path = '${CONFIG_PATH}' or via default 'config.cgf.defaults'";
    else
		echo "Iterating through example strings array from config file...";
		printf "\n";
		index=$((1))
		for example_string in "${example_strings_array[@]}"
		do
		    echo "Example string ${index} = '${example_string}'"
		    index=$((index+1))
		done
		printf "\n"
    fi
fi
# reset CONFIRMATION environment variable for next time
CONFIRMATION="n";

