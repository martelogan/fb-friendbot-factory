# -*- coding: utf-8 -*-
#!/usr/bin/env python

# Script based on https://raw.githubusercontent.com/jddunn/emoter/master/emoter/emoter_corpus_fb_parser.py
# Used to parse fb messages csv (from ownaginatious': https://github.com/ownaginatious/fbchat-archive-parser)
# to the format found at https://github.com/Conchylicultor/DeepQA/tree/master/data/lightweight

# NOTE: The Facebook messages archive must be parsed already and formatted into a CSV file with
# the columns ['thread'], ['sender'], ['date'], and ['message'].

from fb_messages_args_parsing import *
from fb_messages_helpers import *

import csv

# GLOBAL VARIABLES

target_user_name = ""
structured_facebook_data_infile_path = ""
parsed_facebook_data_output_path = ""
allowed_words_per_sentence = 0
cur_conversation = []


# PARSING OPERATIONS


def encode_to_utf8(message):
    return message.decode('utf-8', 'ignore').encode("utf-8")


def attempt_append_to_cur_conversation(message_dict):
    if (not message_dict):
        return False
    message = message_dict["message"]
    if (not message) or(len(message.split()) > allowed_words_per_sentence):
        return False
    message = encode_to_utf8(message)
    if message:
        cur_conversation.append(message)
        return True
    return False


def write_deepqa_conversation_to_file(outfile_path):
    global cur_conversation
    if len(cur_conversation) <= 1:
        return
    with open(r'' + outfile_path, mode="a") as outfile:
        for s in cur_conversation:
            outfile.write("%s\n" % s)
        outfile.write("===\n")
    cur_conversation = []
    

# PUBLIC INTERFACE


def set_parsing_global_vars(argu):
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
    set_parsing_global_vars(argu)
    formatted_target_user_name_str = target_user_name.lower().replace(" ", "_")
    outfile_path = parsed_facebook_data_output_path + "/" + formatted_target_user_name_str + "-" + str(allowed_words_per_sentence) + '.txt'
    delete_leftover_content(outfile_path)
    execute_on_all_conversations(argu, outfile_path, attempt_append_to_cur_conversation, write_deepqa_conversation_to_file)
    print "\n\tFinished parsing and exporting trainable corpus for target user '{}' constrained to sentence length '{}' ".format(target_user_name.replace("\\", ""), allowed_words_per_sentence)

##############################################################################
#                               MAIN
##############################################################################


if __name__ == "__main__":
    arguments = arg_parsing()
    arguments.func(arguments)
