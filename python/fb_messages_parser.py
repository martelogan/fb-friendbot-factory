# -*- coding: utf-8 -*-
#!/usr/bin/env python

# Script based on https://raw.githubusercontent.com/jddunn/emoter/master/emoter/emoter_corpus_fb_parser.py
# Used to parse fb messages csv (from ownaginatious': https://github.com/ownaginatious/fbchat-archive-parser)
# to the format found at https://github.com/Conchylicultor/DeepQA/tree/master/data/lightweight

# NOTE: The Facebook messages archive must be parsed already and formatted into a CSV file with
# the columns ['thread'], ['sender'], ['date'], and ['message'].

from fb_messages_args_parsing import *

import csv

# GLOBAL VARIABLES

target_user_name = ""
structured_facebook_data_infile_path = ""
parsed_facebook_data_output_path = ""
allowed_words_per_sentence = 0
cur_conversation = []


# PRIVATE HELPER FUNCTIONS

def delete_leftover_content(outfile):
    with open(outfile, "w"):
        pass


def encode_to_utf8(message):
    return message.decode('utf-8', 'ignore').encode("utf-8")


def attempt_append_to_cur_conversation(message):
    if (not message) or(len(message.split()) > allowed_words_per_sentence):
        return False
    message = encode_to_utf8(message)
    if message:
        cur_conversation.append(message)
        return True
    return False


def write_deepqa_conversation_to_file(outfile_path):
    if len(cur_conversation) <= 1:
        return
    with open(r'' + outfile_path, mode="a") as outfile:
        for s in cur_conversation:
            outfile.write("%s\n" % s)
        outfile.write("===\n")


def output_deep_qa_conversations(outfile_path):
    global cur_conversation
    # read csv into memory for easy indexing (can't be too large)
    with open(r'' + structured_facebook_data_infile_path, 'r') as csv_to_parse:
        reader = csv.reader(csv_to_parse)
        all_messages = list(reader)
        messages_count = len(all_messages)

    # local variables
    found_non_target_usr_msg = False
    t1_msg = ""
    t1_name = ""
    t2_msg = ""
    row_number = 0

    # iteration for facebook messages parsing
    while row_number < messages_count:
        message_row = all_messages[row_number]
        message_sender = message_row[1]
        if found_non_target_usr_msg:  # investigating conversation started by non-target user
            if message_sender == target_user_name:  # target user has replied!!!
                found_non_target_usr_msg = False
                if not attempt_append_to_cur_conversation(t1_msg):
                    t1_name = ""
                    t1_msg = ""
                    row_number += 1
                    continue
                t1_msg = ""
                t2_msg = str(message_row[3].strip())
                row_number += 1
                next_row = all_messages[row_number]
                next_name = next_row[1]
                is_t2_chain = True
                is_t1_chain = False
                while next_name == target_user_name or next_name == t1_name:  # the 2-way conversation is ongoing...
                    if next_name == target_user_name:
                        if is_t1_chain:
                            attempt_append_to_cur_conversation(t1_msg)
                            t1_msg = ""
                            is_t1_chain = False
                        is_t2_chain = True
                        if t2_msg:
                            t2_msg += ". "
                        t2_msg += str(next_row[3].strip())
                    else:
                        if is_t2_chain:
                            attempt_append_to_cur_conversation(t2_msg)
                            t2_msg = ""
                            is_t2_chain = False
                        is_t1_chain = True
                        if t1_msg:
                            t1_msg += ". "
                        t1_msg += str(next_row[3].strip())
                    row_number += 1
                    if row_number >= messages_count:
                        break
                    next_row = all_messages[row_number]
                    next_name = next_row[1]
                write_deepqa_conversation_to_file(outfile_path)
                cur_conversation = []
                t1_name = ""
                t1_msg = ""
                t2_msg = ""
                continue
            else:  # message is from non-target user
                if message_sender == t1_name:  # continuing previous non-target user message
                    t1_msg += ". " + str(message_row[3].strip())
                else:  # beginning a message from a new non-target user
                    t1_name = str(message_row[1].strip())
                    t1_msg = str(message_row[3].strip())
        elif message_sender != target_user_name:  # starting a new conversation
            found_non_target_usr_msg = True
            t1_name = str(message_row[1].strip())
            t1_msg = str(message_row[3].strip())
        row_number += 1
    print "\n\tFinished parsing and exporting trainable corpus for target user '{}'".format(target_user_name.replace("\\", ""))


def set_global_vars(argu):
    global target_user_name
    global structured_facebook_data_infile_path
    global parsed_facebook_data_output_path
    global allowed_words_per_sentence
    if argu.target_user_name:
        target_user_name = argu.target_user_name
    else:
        target_user_name = raw_input("\n\tEnter the name of the Facebook profile from which to make a text corpus: \n\t")
    if argu.structured_facebook_data_infile_path:
        structured_facebook_data_infile_path = argu.structured_facebook_data_infile_path
    else:
        structured_facebook_data_infile_path = raw_input("\n\tEnter the path to structured facebook data from which to parse a text corpus: \n\t")
    if argu.parsed_facebook_data_output_path:
        parsed_facebook_data_output_path = argu.parsed_facebook_data_output_path
    else:
        parsed_facebook_data_output_path = raw_input("\n\tEnter the outfile path for the parsed facebook text corpus: \n\t")
    if argu.allowed_words_per_sentence != 0:
        allowed_words_per_sentence = argu.allowed_words_per_sentence
    else:
        sentence_length_raw_string = raw_input("\n\tEnter the sentence length (in # words) for which to extract messages: \n\t")
        allowed_words_per_sentence = int(sentence_length_raw_string)


def parse_to_deep_qa(argu):
    set_global_vars(argu)
    formatted_target_user_name_str = target_user_name.lower().replace(" ", "_")
    outfile_path = parsed_facebook_data_output_path + "/" + formatted_target_user_name_str + "-" + str(allowed_words_per_sentence) + '.txt'
    delete_leftover_content(outfile_path)
    output_deep_qa_conversations(outfile_path)

##############################################################################
#                               MAIN
##############################################################################


if __name__ == "__main__":
    arguments = arg_parsing()
    arguments.func(arguments)
