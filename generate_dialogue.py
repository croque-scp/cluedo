#!/usr/bin/env python3

# Takes events.xlsx and prints dialogue.coffee to stdout.

import pandas as pd
import numpy as np

# Load the dialogue sheet as a dateframe.
dialogue_sheet = pd.read_excel("src/events.xlsx")

# Scrap the first row, it's a description of each header.
dialogue_sheet = dialogue_sheet.drop(0)

# Add a coloumn with the spreadsheet row number.
dialogue_sheet['rowid'] = np.arange(3, len(dialogue_sheet) + 3)

print(dialogue_sheet)

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
print("Splitting sheet into frames")
frames = []
frame = []
for index,row in dialogue_sheet.iterrows():
    # If there's an ID, start a new frame
    if row['ID in'] is not np.nan and frame != []:
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

# Solit each frame into a list of LINES
print("Splitting frames into lines")
frames_ = []
for frame in frames:
    lines = []
    line = []
    for row in frame:
        # If there's a LINE, start a new line
        if row['Lines'] is not np.nan and line != []:
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
print("Splitting lines into options")
frames_ = []
for frame in frames:
    lines_ = []
    for line in frame:
        options = []
        option = None # would be type pd.Series
        # line is a list of pd.Series
        for row in line:
            option = row
            options.append(option)
        assert all([isinstance(o, pd.Series) for o in options])
        assert len(options) > 0
        if len(options) > 1:
            assert all([o['Options'] is not np.nan for o in options]), (
                "One of the options for {} (row {}) is missing text".format(
                    options[0]['ID in'], options[0]['rowid']))
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

# once
'''
getEvents = (aic) ->
  events = {
'''
# per event:
'''
    {event_name}: {
      precommand: (aic) ->
        {precommands}
      lines: [
'''
# per line:
'''
        {
          delay: {line_delay}
          duration: {line_duration}
          text: """
                {line_text}
                """
          options: [
'''
# per option in this line
'''
            {
              text: """
                    {option_text}
                    """
              destination: "{option_destination}"
              opinion: {option_opinion}
              condition: (aic) ->
                {option_conditions}
            }
'''
# per line:
'''
          ]
        }
'''
# per event:
'''
      ]
      postcommand: (aic) ->
        {postcommands}
    }
'''
# once
'''
  }
'''
