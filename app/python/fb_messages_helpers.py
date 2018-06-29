# -*- coding: utf-8 -*-
#!/usr/bin/env python

# Helper function for output on facebook messages archive.

# LICENSE INFORMATION HEADER

__author__ = "Logan Martel"
__copyright__ = "Copyleft (c) 2018, Logan Martel"
__credits__ = ["Logan Martel"]
__license__ = "ApacheV2.0"
__version__ = "0.1.0"
__maintainer__ = "Logan Martel"
__email__ = "logan.martel@outlook.com"
__status__ = "Development"

# NOTE: The Facebook messages archive must be parsed already and formatted into a CSV file with
# the columns ['thread'], ['sender'], ['date'], and ['message'].

from fb_messages_args_parsing import *

import csv

# GLOBAL VARIABLES

target_user_name = ""
structured_facebook_data_infile_path = ""


# HELPER METHODS

def delete_leftover_content(outfile):
    with open(outfile, "w"):
        pass


def operate_on_all_conversatons(outfile_path, operation_to_perform_per_message, operation_to_perform_per_conversation):
    # read csv into memory for easy indexing (can't be too large)
    with open(r'' + structured_facebook_data_infile_path, 'r') as csv_to_parse:
        reader = csv.reader(csv_to_parse)
        all_messages = list(reader)
        messages_count = len(all_messages)

    # local variables
    found_non_target_usr_msg = False
    non_target_usr_msg = ""
    non_target_usr_name = ""
    target_usr_msg = ""
    row_number = 0

    # iteration for facebook messages execution
    while row_number < messages_count:
        message_row = all_messages[row_number]
        message_sender = message_row[1]
        if found_non_target_usr_msg:  # investigating conversation started by non-target user
            if message_sender == target_user_name:  # target user has replied!!!
                # reset non-target usr seeking flag for next time
                found_non_target_usr_msg = False
                # attempt operation on latest non_target_usr_msg
                message_dict = {'user': non_target_usr_name, 'message': non_target_usr_msg}
                if not operation_to_perform_per_message(message_dict):
                    # operation failed - skip latest non_target_usr_msg
                    non_target_usr_name = ""
                    non_target_usr_msg = ""
                    row_number += 1
                    continue
                # intentionally reset non_target_usr_msg post-processing
                non_target_usr_msg = ""
                # get current target_usr_msg
                target_usr_msg = str(message_row[3].strip())
                row_number += 1
                next_row = all_messages[row_number]
                next_name = next_row[1]
                # booleans to track chains of messages from one of the two users
                is_target_usr_msg_chain = True
                is_non_target_usr_msg_chain = False
                while next_name == target_user_name or next_name == non_target_usr_name:  # the 2-way conversation is ongoing...
                    if next_name == target_user_name:
                        # message is from target user
                        if is_non_target_usr_msg_chain: # was non_target_usr the last speaker?
                            # if so, attempt the operation on the latest message chain before proceeding
                            message_dict = {'user': non_target_usr_name, 'message': non_target_usr_msg}
                            operation_to_perform_per_message(message_dict)
                            # then reset our running variables
                            non_target_usr_msg = ""
                            is_non_target_usr_msg_chain = False
                        # flag that we are currently in a chain of target_usr messages
                        is_target_usr_msg_chain = True
                        # append any non-empty strings to the running target_usr_msg chain
                        if target_usr_msg:
                            target_usr_msg += ". "
                        target_usr_msg += str(next_row[3].strip())
                    else:
                        # message is from non-target user
                        if is_target_usr_msg_chain: # was target_usr the last speaker?
                            # if so, attempt the operation on the latest message chain before proceeding
                            message_dict = {'user': target_user_name, 'message': target_usr_msg}
                            operation_to_perform_per_message(message_dict)
                            # then reset our running variables
                            target_usr_msg = ""
                            is_target_usr_msg_chain = False
                        # flag that we are currently in a chain of non_target_usr messages
                        is_non_target_usr_msg_chain = True
                        # append any non-empty strings to the running non_target_usr_msg chain
                        if non_target_usr_msg:
                            non_target_usr_msg += ". "
                        non_target_usr_msg += str(next_row[3].strip())
                    row_number += 1
                    # exit loop if there are no more messages
                    if row_number >= messages_count:
                        break
                    # otherwise, cache next message for next loop iteration
                    next_row = all_messages[row_number]
                    next_name = next_row[1]
                # when finished this 2-way conversation, write desired output to file
                operation_to_perform_per_conversation(outfile_path)
                # reset all running variables
                non_target_usr_name = ""
                non_target_usr_msg = ""
                target_usr_msg = ""
                continue
            else:  # message is from non-target user
                if message_sender == non_target_usr_name:  # continuing previous non-target user message
                    non_target_usr_msg += ". " + str(message_row[3].strip())
                else:  # beginning a message from a new non-target user
                    non_target_usr_name = str(message_row[1].strip())
                    non_target_usr_msg = str(message_row[3].strip())
        elif message_sender != target_user_name:  # starting a new conversation
            found_non_target_usr_msg = True
            non_target_usr_name = str(message_row[1].strip())
            non_target_usr_msg = str(message_row[3].strip())
        row_number += 1


def set_helper_global_vars(argu):
    global target_user_name
    global structured_facebook_data_infile_path
    if argu.target_user_name:
        target_user_name = argu.target_user_name
    else:
        target_user_name = raw_input("\n\tEnter the name of the Facebook profile from which to make a text corpus: \n\t")
    if argu.structured_facebook_data_infile_path:
        structured_facebook_data_infile_path = argu.structured_facebook_data_infile_path
    else:
        structured_facebook_data_infile_path = raw_input("\n\tEnter the path to structured facebook data from which to parse a text corpus: \n\t")


def execute_on_all_conversations(argu, outfile_path, operation_to_perform_per_message, operation_to_perform_per_conversation):
    set_helper_global_vars(argu)
    operate_on_all_conversatons(outfile_path, operation_to_perform_per_message, operation_to_perform_per_conversation)

##############################################################################
#                               MAIN
##############################################################################


if __name__ == "__main__":
    arguments = arg_parsing()
    arguments.func(arguments)
