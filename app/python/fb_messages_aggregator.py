# -*- coding: utf-8 -*-
# !/usr/bin/env python

# Script to aggregate some basic stats on facebook messenger convos

# NOTE: The Facebook messages archive must be parsed already and formatted into a CSV file with
# the columns ['thread'], ['sender'], ['date'], and ['message'].

from fb_messages_args_parsing import *
from fb_messages_helpers import *

import os
import sys

# EXTERNAL HELPER CODE

## {{{ http://code.activestate.com/recipes/511478/ (r1)
import math
import functools


def percentile(N, percent, key=lambda x: x):
    """
    Find the percentile of a list of values.

    @parameter N - is a list of values. Note N MUST BE already sorted.
    @parameter percent - a float value from 0.0 to 1.0.
    @parameter key - optional key function to compute value from each element of N.

    @return - the percentile of the values
    """
    if not N:
        return None
    k = (len(N) - 1) * percent
    f = math.floor(k)
    c = math.ceil(k)
    if f == c:
        return key(N[int(k)])
    d0 = key(N[int(f)]) * (c - k)
    d1 = key(N[int(c)]) * (k - f)
    return d0 + d1


# end of http://code.activestate.com/recipes/511478/ }}}


# GLOBAL VARIABLES

target_user_name = ""
structured_facebook_data_infile_path = ""
facebook_data_stats_output_path = ""
target_user_messages_count = 0
target_user_messages_length_sum = 0
target_user_max_message_length = 0
target_user_min_message_length = sys.maxint
target_user_conversations_count = 0
word_counts_list = []


# AGGREGATION OPERATIONS


def update_target_user_message_stats(message_dict):
    global target_user_messages_count
    global target_user_messages_length_sum
    global target_user_max_message_length
    global target_user_min_message_length
    if not message_dict:
        return False
    if not (message_dict["user"] == target_user_name):
        return True
    message = message_dict["message"]
    if message:
        word_count = len(message.split())
        target_user_messages_length_sum += word_count
        target_user_messages_count += 1
        if word_count > target_user_max_message_length:
            target_user_max_message_length = word_count
        elif word_count < target_user_min_message_length:
            target_user_min_message_length = word_count
        word_counts_list.append(word_count)
        return True
    return False


def update_conversations_count(outfile_path):
    global target_user_conversations_count
    target_user_conversations_count += 1


def write_target_user_stats_to_file(outfile_path):
    import csv
    # Append data to cumulative experiments file
    if not os.path.isfile(outfile_path):
        with open(r'' + outfile_path, 'w') as f:
            writer = csv.writer(f)
            headers = ['Target_User_Name', 'Total_Messages_Sent', 'Average_Words_Per_Message',
                       'Median_Words_Per_Message', 'Max_Words_Per_Message',
                       'Min_Words_Per_Message', 'Total_Conversations_Count',
                       'Trainable_Sentence_Length_Lower_Bound', 'Trainable_Sentence_Length_Upper_Bound']
            writer.writerow(headers)
    with open(r'' + outfile_path, 'a') as f:
        writer = csv.writer(f)
        # construct our partial percentile functions
        pct_99 = functools.partial(percentile, percent=0.99)
        median = functools.partial(percentile, percent=0.5)
        pct_25 = functools.partial(percentile, percent=0.25)
        # sort our list of word counts
        sorted_word_counts = sorted(word_counts_list)
        # compute stats
        target_user_messages_average = int(target_user_messages_length_sum / target_user_messages_count)
        target_user_messages_median = int(median(sorted_word_counts))
        trainable_lower_bound = int(pct_25(sorted_word_counts))
        trainable_upper_bound = int(pct_99(sorted_word_counts))
        # write to csv
        fields = [target_user_name, target_user_messages_count, target_user_messages_average,
                  target_user_messages_median, target_user_max_message_length,
                  target_user_min_message_length, target_user_conversations_count, trainable_lower_bound,
                  trainable_upper_bound]
        writer.writerow(fields)


# PUBLIC INTERFACE


def set_aggregator_global_vars(argu):
    global target_user_name
    global structured_facebook_data_infile_path
    global facebook_data_stats_output_path
    if argu.target_user_name:
        target_user_name = argu.target_user_name
    else:
        target_user_name = raw_input(
            "\n\tEnter the name of the Facebook profile from which to make a text corpus: \n\t")
    if argu.structured_facebook_data_infile_path:
        structured_facebook_data_infile_path = argu.structured_facebook_data_infile_path
    else:
        structured_facebook_data_infile_path = raw_input(
            "\n\tEnter the path to structured facebook data from which to parse a text corpus: \n\t")
    if argu.facebook_data_stats_output_path:
        facebook_data_stats_output_path = argu.facebook_data_stats_output_path
    else:
        facebook_data_stats_output_path = raw_input("\n\tEnter the outfile path for the facebook data stats: \n\t")


def aggregate_stats_for_target_usr(argu):
    set_aggregator_global_vars(argu)
    outfile_path = facebook_data_stats_output_path + "/" + 'fb_stats.csv'
    execute_on_all_conversations(argu, outfile_path, update_target_user_message_stats, update_conversations_count)
    write_target_user_stats_to_file(outfile_path)
    print "\n\tFinished aggregating stats for target user '{}'".format(target_user_name.replace("\\", ""))


##############################################################################
#                               MAIN
##############################################################################


if __name__ == "__main__":
    arguments = arg_parsing()
    arguments.func(arguments)
