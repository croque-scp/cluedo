#!/usr/bin/env python3

# Takes events.xlsx and prints dialogue.coffee to stdout.

import sys
import pandas as pd
import numpy as np

# Load the dialogue sheet as a dateframe.
dialogue_sheet = pd.read_excel("src/events.xlsm")

# Scrap the first row, it's a description of each header.
dialogue_sheet = dialogue_sheet.drop(0)

# Add a coloumn with the spreadsheet row number.
dialogue_sheet['rowid'] = np.arange(3, len(dialogue_sheet) + 3)

print(dialogue_sheet, file=sys.stderr)

# The columns are:
    # ID in
    # Image (desc)
    # Image
    # Lines
    # Appears If
    # Options
    # ID out

# cluedo is organised as follows:
    # There is a list of FRAMES.
        # A frame is what's presented to a user. It is the image with the
        # dialogue and it contains any options that they might be able to
        # click.
    # A FRAME is a list of LINES.
        # Each line is a line of text on the page.
    # A LINE is a list of OPTIONS.
        # Each option is a choice that the user might click.
        # The last LINE in a FRAME has its options rendered. The rest are
        # ignored.
        # Most lines, and by extension most frames, have a single undefined
        # options which becomes the "next" button.

# Split the dataframe into a list of FRAMES
print("Splitting sheet into frames", file=sys.stderr)
frames = []
frame = []
for index,row in dialogue_sheet.iterrows():
    # If there's an ID, start a new frame
    if pd.notna(row['ID in']) and frame != []:
        frames.append(frame)
        frame = []
    # Otherwise, add this row to the frame
    frame.append(row)
# The last frame wasn't saved, so do that now
frames.append(frame)

# Check that frame IDs are unique
frame_ids = [frame[0]['ID in'] for frame in frames]
dupe_frames = [frame[0] for frame in frames
               if frame_ids.count(frame[0]['ID in']) > 1]
assert len(dupe_frames) == 0, (
    "Frame IDs must be unique. Duplicates: {}".format(
        ", ".join(["{} on row {}".format(frame['ID in'], frame['rowid'])
                   for frame in dupe_frames])))

# Check that frames are accessible
target_ids = [row['ID out'] for frame in frames for row in frame
              if pd.notna(row['ID out'])]
untargeted_ids = set(frame_ids) - set(target_ids)
if len(untargeted_ids) > 0:
    print("WARNING: The following frames are inaccessible: {}".format(
        ", ".join(untargeted_ids)), file=sys.stderr)

# Check that option targets exist
unwritten_ids = set(target_ids) - set(frame_ids)
if len(unwritten_ids) > 0:
    print("WARNING: The following frames do not exist: {}".format(
        ", ".join(unwritten_ids)), file=sys.stderr)

# Solit each frame into a list of LINES
print("Splitting frames into lines", file=sys.stderr)
frames_ = []
for frame in frames:
    lines = []
    line = []
    for row in frame:
        # If there's a LINE, start a new line
        if pd.notna(row['Lines']) and line != []:
            lines.append(line)
            line = []
        # Otherwise, add this row to the line
        line.append(row)
    # The last line wasn't saved, so do that now
    lines.append(line)
    frames_.append(lines)
frames = frames_

# Split each line into a list of OPTIONS
# It is expected that the vast majority of lines will have one, empty option.
print("Splitting lines into options", file=sys.stderr)
frames_ = []
for frame in frames:
    lines_ = []
    for line in frame:
        options = []
        option = None # would be type pd.Series
        # line is a list of pd.Series
        for row in line:
            option = row
            if pd.notna(option['Lines']):
                option['Lines'] = option['Lines'].replace("\"", "\\\"")
            options.append(option)
        assert all([isinstance(o, pd.Series) for o in options])
        assert len(options) > 0
        if len(options) > 1:
            assert all([pd.notna(o['Options']) for o in options]), (
                "One of the options for {} (row {}) is missing text".format(
                    options[0]['ID in'], options[0]['rowid']))
            assert all(pd.isna(o['precommands']) for o in options[1:]), (
                "precommands can only be on the first option of a frame ({}, "
                "row {})".format(options[0]['ID in'], options[0]['rowid']))
            assert all(pd.isna(o['postcommands']) for o in options[1:]), (
                "postcommands can only be on the first option of a frame ({}, "
                "row {})".format(options[0]['ID in'], options[0]['rowid']))
        lines_.append(options)
    frames_.append(lines_)
frames = frames_

# Dialogue is now stored in a nested list:
    # Frames -> Lines -> Options

# Start converting it to coffeescript

# What does dialogue.coffee need?
    # 1. A dict, with the dialogue
    # 2. The dict should also have the action associated with each option

# Unlike maitreya, there is no dialogue associated with the option, only the
# Line
# However, only an Option can have an Appears If, but a Line will not appear if
# it has no Options that appear

format = {
    'start': '''\
get_events = (aic) ->
  events = {
''',
    'event_start': '''\
    {event_name}: {{
      conversation: '{conversation}'
      precommand: (aic) -> {precommands}
      postcommand: (aic) -> {postcommands}
      lines: [
''',
    'precommand': "\n        {}",
    'postcommand': "\n        {}",
    'line_start': '''\
        {{
          delay: {delay}
          duration: {duration}
          text: "{text}"
          style: [{style}]
          options: [
''',
    'option_start': '''\
            {{
              text: "{text}"
              destination: '{destination}'
              style: [{style}]
              opinion: {opinion}
              oncommand: (aic) -> {oncommands}
              conditions: [{conditions}
''',
    'oncommand': "\n                {}",
    'condition': "\n                (aic) -> {}",
    'option_end': '''\
              ]
            }
''',
    'line_end': '''\
          ]
        }
''',
    'event_end': '''\
      ]
    }
''',
    'end': '''\
  }
'''
}

final_output = format['start']
for frame in frames:
    precommands = frame[0][0]['precommands']
    postcommands = frame[0][0]['postcommands']
    event_output = format['event_start'].format(
        event_name=frame[0][0]['ID in'],
        conversation="default",
        # XXX the following doesn't preserve indent for multiline
        precommands="return" if pd.isna(precommands) else
                     "".join([format['precommand'].format(c)
                              for c in precommands.splitlines()]),
        postcommands="return" if pd.isna(postcommands) else
                     "".join([format['postcommand'].format(c)
                              for c in postcommands.splitlines()]))
    for line in frame:
        line_output = format['line_start'].format(
            # TODO delay and duration
            delay="\"auto\"",
            duration="\"auto\"",
            text="" if pd.isna(line[0]['Lines']) else
                 "\\n".join(line[0]['Lines'].splitlines()),
            style="" if pd.isna(line[0]['lc']) else
                  str(line[0]['lc'].splitlines())[1:-1])
        for option in line:
            oncommands = option['oncommands']
            conditions = option['Appears If']
            option_output = format['option_start'].format(
                text="" if pd.isna(option['Options'])
                        else option['Options'],
                destination="" if pd.isna(option['ID out'])
                               else option['ID out'],
                opinion=0,
                style="" if pd.isna(option['oc']) else
                      str(option['oc'].splitlines())[1:-1],
                oncommands="return" if pd.isna(oncommands) else
                           "".join([format['oncommand'].format(c)
                                    for c in oncommands.splitlines()]),
                conditions="" if pd.isna(conditions) else
                           "".join([format['condition'].format(c)
                                    for c in conditions.splitlines()]))
            option_output += format['option_end']
            line_output += option_output
        line_output += format['line_end']
        event_output += line_output
    event_output += format['event_end']
    final_output += event_output
final_output += format['end']

print("# Generated by generate_dialogue.py")
print(final_output)
