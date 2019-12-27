getEvents = (aic) ->
  events = {
    wake_up: {
      precommand: (aic) ->
        null
      lines: [
        {
          delay: "auto"
          duration: "auto"
          text: """
                The evening is misty, foggy and cold.
                Another long night of doing what you're told.
                """
          options: [
            {
              text: """
                    Next
                    """
              destination: "another_event"
              opinion: 0
              condition: (aic) ->
                true
            }
          ]
        }
      ]
      postcommand: (aic) ->
        null
    }
    # old version be like:
    drive_there: [0, 0, "Your car starts slowly, its engine does sputter,\nYour exhausted complaint is barely a mutter.", 0, 0, "The drive there is lonely. The sky’s growing dark.\nYou like it. The contrast with daytime is stark."],
  }
