# cluedo.js, the workhorse behind SCP-5000
# Written by Croquembouche, released under MIT

"use strict"

### global $, angular ###

assert = (condition, message) ->
  unless condition
    throw new Error(message ? "AssertionError")

# randomise an array
shuffle = (array) ->
  m = array.length
  t = undefined
  i = undefined
  while m
    i = Math.floor(Math.random() * m--)
    t = array[m]
    array[m] = array[i]
    array[i] = t
  return array

do ->

  MaitreyaController = ($scope, $timeout, $sce, $http) ->
    aic = this

    LoopService.use $scope
    # give BreachLoopService our scope
    # the LoopService service (from LoopService.js) contains the interactions for Breach, Alexandra and D-Class generated from the spreadsheet

    $scope.trustAsHtml = (string) ->
      $sce.trustAsHtml string

    aic.bootDate = new Date(new Date(Date.now()).setFullYear(2018))
    auto = 'auto'
    aic.lang = {} # This object contains all strings that aren't dialogue
    speech = # This object contains all dialogue strings
      merge: (dialogue) ->
        # merges dialogue from LoopService into this variable
        console.log "Merging dialogue..."
        for own bigSection,section of dialogue
          if this.hasOwnProperty(bigSection)
            # if speech already has the bigSection, we can't overwrite it, we
            # just need to dupe its inner values
            for own speaker of section
              console.log "...#{bigSection} of #{speaker}"
              this[bigSection][speaker] = dialogue[bigSection][speaker]
          else
            # if speech does not have the bigSection, hell yeah let's
            # overwrite that shit
            console.log "...new #{bigSection}"
            this[bigSection] = dialogue[bigSection]
        return null

    # Initial setup for once the page has loaded
    $(document).ready ->
      aic.onMobile = $('body').width() < 700
      $scope.$apply ->
        aic = aic_init(aic) # from init.js
        aic.lang = getBaseLexicon(aic)['lang'] # from lang.coffee
        speech.merge getBaseLexicon(aic)['speech'] # from lang.coffee
        speech.merge LoopService.dialogue
      preloadImage aic.lang.images.greyStripe
      console.log "Ready to go"
      return null

    # called when "BOOT UP" is clicked from preload
    aic.bootUp = =>
      console.log "Booting up..."
      aic.preload = false
      # Here we go boys
      aic.start[0] aic.start[1], aic.start[2]
      return null

    aic.mainLoop = (event_name) ->
      # TODO add character/sheet property to events
      event_name = event_name.replace(/_*$/g, "")
      console.log "Event = #{event_name}"

      if event_name in aic.blacklist
        throw new Error("#{event_name} is blacklisted")

      if event_name of aic.events
        execute_event aic.events[event_name]
      else
        throw new Error("#{event_name} is not an event")

    execute_event = (event) ->
      # Function for executing a single event.
      # Receives the event, not the name.

      # Work out which of the lines have options.
      lines = []
      for line in event['lines']
        options = []
        for option in line['options']
          conditions = []
          for condition in option['conditions']
            conditions.push condition()
          options.push conditions.every((v) => v is true)
        if options.every((v) => v is true) then lines.push line
      # lines is now all the lines that will appear
      # write the lines, one by one, and display options of the final
      render_lines lines

    ### PROCESSING FUNCTIONS ###

    # pass options to chatLog for presentation to the user

    presentOptions = (line) ->
      # present the options for this line

      # options list may not be empty:
      aic.chatLog[conversation].options = []
      # if ids is "CLEAR", stop here, we only want to clear the array
      if line is 'CLEAR'
        return null

      #$scope.$apply(() ->
      aic.chatLog[conversation].options = line['options']
      #)

      return null

    # structure dialogue and calculate timing

    # writeDialogue = (conversation, dialogueList, speaker, event_name) ->
    writeDialogue = (event) ->
      ## An event is a list of lines
      speaker = event['speaker']
      # event_name is not always present, but we need it
      # it may be "undefined", deal with that later
      # deep copy the dialogue to protect the original
      dialogueList = dialogueList.slice()
      n1 = undefined
      n2 = undefined
      messages = []
      totalDelay = 0
      # emote = undefined
      for line in event['lines']
        delay = line['delay']
        duration = line['duration']
        if delay is 'auto' then delay = aic.typingDelay
        if duration is 'auto' then duration = aic.typingSpeed * line['text'].length
        assert typeof delay is 'number' and typeof duration is 'number'
        ## XXX check that opinion is propagated, may have just deleted the logic
        # obviously maitreya also always speaks instantly
        # correction: maitreya does not speak instantly, because that fucking sucks
        ## TODO XXX TODO XXX TODO change 'maitreya' to 'player' or similar
        if speaker is 'maitreya'
          # but we want the first message to be instant
          if i is 0 then duration = 0
          else if duration > 1
            # and then make her speak a little bit faster anyway
            duration *= 0.5

        # if the cheat is on, everyone speaks instantly
        if aic.cheats.impatientMode
          delay = 0
          duration = 0.1 # if 0 then messages appear in wrong order
        cssClass = line['style']
        # mode = undefined
        ## TODO if typed in style then n2 *= 2 and cssClass = typed and mode = typing
        ## TODO alex's emotions are not css classes (ng-src):
        # if speaker == 'alexandra' and text.length > 0
        #   if !!/(^\w*?):/.exec(text)
        #     emote = /(^\w*?):/.exec(text)[1]
        #     if !aic.alexandraEmotionList.includes(emote)
        #       throw new Error("Alexandra is experiencing an invalid emotion: #{emote}")
        #     text = text.substring(emote.length + 1)
        #   else
        #     # if no emotion is specified, maintain the last one, or default
        #     emote = emote ? aic.alexandraEmotionList[0]
        messages.push [delay, duration, {
          speaker: force ? speaker
          cssClass: cssClass
          text: line['text'].wikidot_format()
          # mode: mode ? 'default'
          # emote: emote
        }]
        totalDelay += delay + duration
        # record the previous speaker, but only if there was actually a message
        if text.length > 0
          aic.vars.lastSpeaker = force or speaker
        # reset everything for the next iteration
        # mode = 'default'
      pushToLog event['speaker'], messages, event_name
      # the total length of all messages gets passed back to the mainloop
      return totalDelay

    # push dialogue to chatLog for presentation to the user
    pushToLog = (conversation, messages, ID, thread) ->
      # TODO document what the fuck is in messages argument
      # check the dialogue's ID (ie event_name)

      ###if(!ID && conversation !== "terminal") {
      throw new Error("ID was not passed to pushToLog");
      }
      ###

      # next check if this iteration of pushToLog actually has permission to push To Log

      ###var hasControl = false;
      thread = thread || Math.floor(100000 + Math.random() * 900000); // give this thread a random identifiable ID
      // currentlyPushing must be set to this unique value so that other instances know that we have control
      if(currentlyPushing[conversation] !== false && currentlyPushing[conversation] !== thread) {
      // another instance is using this thread
      // ...but we don't care. newer threads get priority, for now
      // take control anyway. the other thread will be notified passively
      currentlyPushing[conversation] = thread;
      hasControl = true;
      } else if(currentlyPushing[conversation] === false) {
      // no one is using this thread, we're good to go
      // take control of the thread
      currentlyPushing[conversation] = thread;
      hasControl = true;
      } else if(currentlyPushing[conversation] === thread) {
      // this thread still has control
      // no need to do anything
      hasControl = true;
      } else {
      throw new Error("Unknown pushToLog thread ownership situation in #{conversation} - new " + thread + " vs old " + currentlyPushing[conversation]);
      }
      ###

      # we should only be handling one ID per character at any given time.
      # if the redundancies are set up correctly, ID should be unique for every interaction.
      # what we are going to do:
      #   check if the queue (per character) is empty
      #   if it it, great, carry on as normal.
      #   if it's not, add the ID to the queue.
      #     will need to find a way to pass the time delay back up to the loop function, but shouldn't be necessary for now
      #   if we added the ID to the queue, abort.
      #   if we didn't, then at the end of the function, get the next item in the queue and pushToLog it
      #     make sure to splice the queue
      # goal of this is to allow for cancelling messages in the future more easily as well as making sure that pushToLog is not running more than once per character
      # TODO: reconfigure writeDialogue so that it also passes the ID
      # conversation: terminal, breach, etc
      # messages: [n1, n2, message]
      # message: {speaker:; cssClass:; text:}
      n1 = messages[0][0]
      n2 = messages[0][1]
      # this is a recursive function
      # the messages[0] is deleted at the end of the operation, moving the rest of the array down, so we only ever need to access messages[0]
      # check for control. will need to do this when doing anything after a timer

      ###if(!stillHasControl(0)) return;###

      timeOut1 = $timeout((->
        # delete this timeOut from the list
        aic.timeOutList[conversation].splice aic.timeOutList[conversation].indexOf([
          timeOut1
          conversation
        ]), 1

        ###if(!stillHasControl(1)) return;###

        # obviously, don't show the wait icon when we're speaking

        ###
        if(messages[0][2].speaker === "maitreya") {
        // this shows the marker for maitreya, but we only want this if we aren't the *only* maitreya message in the chain
        // 1st check: if the next speaker is maitreya, then obviously the chain is longer than 1
        // 2nd check: if we're already showing the marker, then the chain is definitely longer than 1
        if((messages.length > 1 && messages[1][2].speaker === "maitreya") || aic.isProcessing[conversation]) {
        aic.isProcessing[conversation] = true;
          }
        } else if(n2 > 0) { // we only want to trigger the wait at all if n2 > 0
        aic.isSpeaking[conversation] = true;
        aic.isProcessing[conversation] = false;
        // check to see whether breach is speaking or typing
        if(messages[0][2].speaker === "breach") {
        aic.vars.breachEntryMode = messages[0][2].mode || "speaking";
          }
        }
        ###

        if n2 > 0
          # we only want to trigger the wait at all if n2 > 0
          if messages[0][2].speaker is 'maitreya' and messages.length > 0
            aic.isProcessing[conversation] = true
          else
            aic.isSpeaking[conversation] = true
            aic.isProcessing[conversation] = false
            # check to see whether breach is speaking or typing
            if messages[0][2].speaker is 'breach'
              aic.vars.breachEntryMode = messages[0][2].mode or 'speaking'
        timeOut2 = $timeout((->
          # delete this timeOut from the list
          aic.timeOutList[conversation].splice aic.timeOutList[conversation].indexOf([
            timeOut2
            conversation
          ]), 1

          ###if(!stillHasControl(2)) return;###

          # now we need to check to see if any other messages are still coming through (HINT: they shouldn't be, but just in case)
          if aic.timeOutList[conversation].length is 0
            aic.isSpeaking[conversation] = false
            # check if the next message is ours for marker smoothness
            if messages.length > 1
              if messages[1][2].speaker is not 'maitreya'
                aic.isProcessing[conversation] = false
              # XXX so this is making the processing icon hang for a moment after maitreya's last message
              # I have no clue why it's doing this
              # correction: it actually hangs until the next message comes through. this is a problem
              # this would be because we don't force terminate it at the end of the dialogue?
            else
              aic.isProcessing[conversation] = false
              # this fixes the above
          if !!aic.isSkipping[conversation]
            # check to see if we're being interrupted
            # the value of isSkipping[c] is either false or a character-bigSection-event_name array indicating where to go afterwards
            console.log "Now interrupting: #{conversation}"
            # loop through timeoutlist and kill all timeouts?
            # maybe associate each timeout with its conversation in the list so we can selectively kill them
            timeout = 0
            while timeout < aic.timeOutList[conversation].length
              $timeout.cancel aic.timeOutList[conversation][timeout][0]
              aic.timeOutList[conversation].splice aic.timeOutList[conversation].indexOf(timeout), 1
              # cancel the timer associated with the messages itself
              #$timeout.cancel(aic.timers[conversation]); // commented because not sure why this is needed
              # skip ahead to the requested conversation section
              #TODO: if the (dialogue that's being interrupted) has already queued the next line (ie loopThrough==true), then the current dialogue will be cancelled but the upcoming dialogue will not
              if ID is not undefined
                aic.blacklist.push ID
                console.log "Blacklisting #{ID} (via pushToLog)"
              else
                console.log "Did not blacklist \'undefined\' (via pushToLog)"
              try
                aic.dynamicLoop aic.isSkipping[conversation][0], aic.isSkipping[conversation][1], aic.isSkipping[conversation][2]
                # aic.isSkipping gets cleared in dynamicLoop
              catch e
                console.error e
                throw new Error("Unexpected interruption")
              timeout++
            # this entire interruption check may be bypassed by currentlyPushing, actually
            # ...which is itself bypassed by the blacklist?
            # honestly have no idea what's going on
            # TODO clean up obsolete comments
            aic.isSkipping[conversation] = false
          else
            if aic.blacklist.includes(ID)
              console.error "WARNING: Tried to push #{ID} but it was blacklisted (via pushToLog)"
              # should never actually reach this point, but we do sometimes. final check.
            else
              # don't push the message if it's empty
              if messages[0][2].text.length > 0
                # also don't push it if we don't have control

                ###if(hasControl) {###

                aic.chatLog[conversation].log.unshift messages[0][2]
                addNotification conversation

                # alex's pfp will change
                if messages[0][2].speaker is 'alexandra'
                  aic.vars.alexandraLastEmotion = messages[0][2].emote

                ###}###

              messages.shift()
              if messages.length > 0
                # send the next message
                pushToLog conversation, messages, ID
              else
                # no more messages. we're done here
                # if we have control, declare that we're releasing it

                ###if(hasControl) {
                currentlyPushing[conversation] = false;
                }
                ###

          return null
        ), n2 * 1000, true)
        aic.timeOutList[conversation].push [
          timeOut2
          conversation
        ]
        return null
      ), n1 * 1000, true)
      aic.timeOutList[conversation].push [
        timeOut1
        conversation
      ]

      ###function stillHasControl(timeout) {
      // check whether or not the current thread has control
      console.log(currentlyPushing[conversation] + " has control");
      if(currentlyPushing[conversation] === false) {
      throw new Error("currentlyPushing is false but a pushToLog thread (#{thread}) is running");
        } else if(currentlyPushing[conversation] === thread) {
        // this thread still has control
        console.log(thread + " still has control");
        hasControl = true;
        return true;
        } else {
        // this thread no longer has control
        hasControl = false;
        console.log("pushToLog thread #{thread} interrupted by " + currentlyPushing[conversation] + " at " + timeout);
        return false;
        }
      }
      ###

      return null

    # add notifications to apps/speakers

    addNotification = (target) ->
      # accepts apps as well as conversations as targets
      if aic.speakerList.includes(target)
        if aic.selectedApp is not 'messages' or aic.selectedSpeaker is not target
          aic.notifications[target]++
      else
        if aic.selectedApp is not target
          aic.notifications[target]++
      return null

    # calculate the difference between two dates

    aic.dateDiff = (date1, date2) ->
      diff = Math.floor(date1.getTime() - date2.getTime())
      secs = Math.floor(diff / 1000)
      mins = Math.floor(secs / 60)
      hours = Math.floor(mins / 60)
      days = Math.floor(hours / 24)
      months = Math.floor(days / 31)
      years = Math.floor(months / 12)
      months = Math.floor(months % 12)
      days = Math.floor(days % 31)
      hours = Math.floor(hours % 24)
      mins = Math.floor(mins % 60)
      secs = Math.floor(secs % 60)
      message = ""
      if days <= 0
        if hours > 0
          message += "#{hours} hours "
        if mins > 0
          message += "#{mins} min "
        if hours < 1
          message += "#{secs} sec "
      else
        if years > 0
          message += "#{years} years, "
        if months > 0 or years > 0
          message += "#{months} months and "
        message += "#{days} days"
      message

    # assign a room to a d-class
    aic.assignRoom = ->
      room = aic.vars.availableRooms[Math.floor(Math.random() * aic.vars.availableRooms.length)]
      index = aic.vars.availableRooms.indexOf(room)
      if index > -1
        aic.vars.availableRooms.splice index, 1
      else
        throw new Error("Bad room")
      room = "s#{room}"
      # TODO tell the room which d class is now in it
      room

    # constructor function for characters
    aic.Actor = (name, role, location) ->
      me = this
      if Array.isArray(name)
        me.firstName = name[0]
        me.lastName = name[1]
        me.name = "#{me.firstName} #{me.lastName}"
      else
        me.name = name
      me.location = location
      # role is an object and expects id, status, allegiance, type
      unless (role.id? and role.status? and role.allegiance? and role.type?)
        throw new Error("#{me.name} is missing role info")
      me.id = role.id
      if role.status in ['ok', 'dead']
        me.status = role.status
      else throw new Error("#{me.name} has an invalid role status")
      if role.allegiance in ['scp', '4000', 'ci']
        me.allegiance = role.allegiance
      else throw new Error("#{me.name} has an invalid role allegiance")
      if role.type in ['dr', 'aic', 'scp', 'd']
        me.type = role.type
      else throw new Error("#{me.name} has an invalid role type")
      switch me.type
        when 'aic' then me.opinion = 5
        when 'd' then me.opinion = -5
        else me.opinion = 0

    preloadAlexandraFaces = ->
      for _,source of aic.lang.images.alexandraLogo
        preloadImage source

    preloadImage = (source) ->
      image = new Image
      image.src = source


    # called when user switches app via buttons or terminal
    aic.switchApp = (app_name) ->
      if app_name is aic.selectedApp
      else unless aic.ready[app_name]
      else if app_name in aic.appList
        if app_name is 'messages'
          aic.notifications[aic.selectedSpeaker] = 0
        else
          aic.notifications[app_name] = 0
        aic.vars["#{app_name}Emphasis"] = false
        aic.selectedApp = app_name
        if app_name is 'terminal'
          # this doesn't work if it's executed instantly
          $timeout (-> $('#terminal-input')[0].focus()), 100
      else
        throw new Error("Tried to switch to unknown app #{app_name}")

    # called when the user switches speaker in the messages app
    aic.switchSpeaker = (speaker) ->
      if speaker is aic.selectedSpeaker
      else unless aic.ready[speaker]
      else
        aic.selectedSpeaker = speaker
        aic.notifications[speaker] = 0

    # called when the user switches operations in the run app
    aic.switchOperation = (operation) ->
      if operation is aic.selectedOperation
        # this is already the selected operation, do nothing
      else if aic.ready[operation] is false
        # this operation is disabled, do nothing
      else
        aic.selectedOperation = operation
      return null

    # called when the user switches articles in the database app

    aic.switchArticle = (article) ->
      console.log "Switching to article: #{article}"
      # specific exception for tutorial
      if aic.vars.waitingForRead4000 is true and article is 'scp4000'
        aic.vars.waitingForRead4000 = false
        alexandraLoop 'TUTORIAL', 'tut5'
      if article is aic.selectedArticle
        # this is already the selected article, do nothing
      else if article is 'menu'
        # we're selecting the menu, which is always enabled
        aic.selectedArticle = 'menu'
        # however, because we're only using 1 section for all articles, we need to force a 0.6s delay so the css can catch up
        $timeout (->
          aic.selectedArticleData = {}
          return null
        ), 600, true
      else if aic.lang.articles[article].available is false
        # this article is disabled, do nothing
      else
        # take all of the data from the articles db and wham that shit into selectedArticleData
        aic.selectedArticleData.type = if Array.isArray(aic.lang.articles[article].text) then 'text' else 'url'
        if aic.selectedArticleData.type is 'text'
          # clear previous article's content, if any
          aic.selectedArticleData.content = []
          # set the Last Revised date
          aic.selectedArticleData.time = new Date(aic.lang.articles[article].revised)
          if aic.selectedArticleData.time.toDateString() is (new Date).toDateString()
            # if the date is today
            aic.selectedArticleData.time = aic.dateDiff(new Date(Date.now()), aic.selectedArticleData.time) + aic.lang.articleRevisedAgo
          else
            aic.selectedArticleData.time = aic.selectedArticleData.time.toLocaleDateString(aic.lang.language,
              year: 'numeric'
              month: 'long'
              day: 'numeric')
          # add each line of content to the article
          i = 0
          while i < aic.lang.articles[article].text.length
            aic.selectedArticleData.content.push aic.lang.articles[article].text[i].wikidot_format()
            i++
        else
          # TODO: create redirection page
          aic.selectedArticleData.content = aic.lang.defaultArticle
        aic.selectedArticle = article
      return null

    # Called when the user submits text via the terminal
    # Effectively terminalLoop() except it always shows the input

    aic.processTerminalInput = ->
      if aic.terminalInput.length > 0
        ## TODO make this compatible with new lines
        writeDialogue 'terminal', [0,0,aic.terminalInput], 'input'
        phrases = aic.terminalInput.split(aic.lang.commands.separator)
        try
          # Add the used command to a list of previous commands
          aic.commandsUsed.unshift phrases.join(aic.lang.commands.separator)
          switch true
            when aic.lang.commands.boot.includes(phrases[0].toLowerCase())
              # BOOT
              aic.bootUp()
            when aic.lang.commands.change.includes(phrases[0].toLowerCase())
              # CHANGE APP
              aic.switchApp phrases[1].toLowerCase()
            when aic.lang.commands.help.includes(phrases[0].toLowerCase())
              # HELP
              writeDialogue 'terminal', speech.misc.terminal.help
            when aic.lang.commands.wipe.includes(phrases[0].toLowerCase())
              # WIPE
              if aic.wipeTimer
                if typeof phrases[1] is 'string'
                  if phrases[1].toLowerCase() is 'confirm'
                    # TODO reset everything then refresh
                    # same function that will be called at the end of the game
                    writeDialogue 'terminal', [ "I haven\'t implemented wipe yet" ]
                console.log 'wiping'
              else
                writeDialogue 'terminal', speech.misc.terminal.wipeSure
                aic.wipeTimer = true
                $timeout (->
                  aic.wipeTimer = false
                  return null
                ), 60000
            when aic.lang.commands.cheat.includes(phrases[0].toLowerCase())
              # CHEAT
              if typeof phrases[1] is 'string'
                switch phrases[1].toLowerCase()
                  when aic.lang.commands.cheats.impatient
                    aic.cheats.impatientMode = !aic.cheats.impatientMode
                    writeDialogue 'terminal', speech.misc.terminal.cheatSuccess
                  when aic.lang.commands.cheats.shut
                    aic.preload = true
                    writeDialogue 'terminal', speech.misc.terminal.cheatSuccess
                  when aic.lang.commands.cheats.print
                    m = eval(phrases[2])
                    console.log m
                    switch typeof m
                      when 'number'
                        m = m.toString()
                        writeDialogue 'terminal', [
                          0, 0, "#{phrases[2]}: #{m}"
                        ]
                      when 'string'
                        writeDialogue 'terminal', [
                          0, 0, "#{phrases[2]}: #{m}"
                        ]
                      else
                        writeDialogue 'terminal', speech.misc.terminal.printDone
                  when aic.lang.commands.cheats.skip
                    if aic.chatLog.breach.log.length is 0
                      writeDialogue 'terminal', speech.misc.terminal.introSkipped
                      aic.isSkipping.terminal = true
                      breachLoop 'INTRODUCTION', 'start'
                    else
                      writeDialogue 'terminal', speech.misc.terminal.skipFailed
                  else
                    throw new Error("Unknown cheat code: #{phrases[1]}")
              else
                writeDialogue 'terminal', speech.misc.terminal.cheatWarn
            when aic.lang.commands.cheats.skip.includes(phrases[0].toLowerCase())
              if aic.chatLog.breach.log.length is 0
                writeDialogue 'terminal', speech.misc.terminal.introSkipped, 'terminal', 'introSkipped'
                aic.isSkipping.terminal = [
                  'breach'
                  'INTRODUCTION'
                  'startSkipped'
                ]
                aic.blacklist.add 'start'
              else
                writeDialogue 'terminal', speech.misc.terminal.skipFailed
            else
              throw new Error("Unknown command: #{phrases[0]}")
        catch error
          # TODO add to terminal conversation
          console.error error.message
          error.name = ''
          writeDialogue 'terminal', [
            0
            0.3
            "e:#{error.message}"
          ]
        aic.terminalInput = ''
      return null

    # When the user presses UP in the terminal, give them the last command that they used
    commandsUsedIterator = -1
    aic.previousCommand = (event) ->
      if event.key is 'ArrowUp' or event.keyCode is 38 or event.which is 38
        # Iterate through the previous commands to check which one to give them
        if commandsUsedIterator < aic.commandsUsed.length - 1
          commandsUsedIterator++
        if aic.terminalInput is not aic.commandsUsed[commandsUsedIterator]
          aic.terminalInput = aic.commandsUsed[commandsUsedIterator]
      else if event.key is 'ArrowDown' or event.keyCode is 40 or event.which is 40
        if commandsUsedIterator > 0
          commandsUsedIterator--
        if aic.terminalInput is not aic.commandsUsed[commandsUsedIterator]
          aic.terminalInput = aic.commandsUsed[commandsUsedIterator]
      else
        # If it wasn't UP or DOWN, clear the iterator
        commandsUsedIterator = -1
      return null

    # hover/unhover rooms - had to use jQuery for this and I despise it
    $('.sitemap').on 'mouseenter', '.room', ->
      room = this.getAttribute('data-room-name')
      $scope.$apply -> aic.vars.hoveredRoom = room
      aic.vars.doingRoom = true
    $('.sitemap').on 'mouseleave', '.room', ->
      if aic.vars.doingRoom
        $scope.$apply -> aic.vars.hoveredRoom = 'none'
        aic.vars.doingRoom = false
    # make the bouncy effect on the article selectors persist when the mouse is moved off them too quickly
    $('.articles-list').on 'mouseenter', '.article-selector', ->
      article = this.getAttribute('data-article')
      # check if there's a timer set by the mouseleave event - if there is, cancel it, because we're resetting it
      if !Number.isInteger(aic.lang.articles[article].cantUnhoverUntil)
        $timeout.cancel aic.lang.articles[article].cantUnhoverUntil
      $scope.$apply -> aic.lang.articles[article].hovered = true
      aic.lang.articles[article].cantUnhoverUntil = Date.now() + 675
    $('.articles-list').on 'mouseleave', '.article-selector', ->
      # this event only fires when the mouse is moved off a selector.
      article = this.getAttribute('data-article')
      # work out how much time is left before this article can be safely unhovered
      timeRemaining = aic.lang.articles[article].cantUnhoverUntil - Date.now()
      if timeRemaining < 0
        # if we're out of time, mark as UNHOVERED, no questions asked
        $scope.$apply -> aic.lang.articles[article].hovered = false
      else
        # if there's still time remaining, set a timer to mark it as UNHOVERED once the timer has expired
        aic.lang.articles[article].cantUnhoverUntil = $timeout((->
          aic.lang.articles[article].hovered = false
          # after the timer has completed successfully, delete it, just in case
          if !Number.isInteger(aic.lang.articles[article].cantUnhoverUntil)
            aic.lang.articles[article].cantUnhoverUntil = undefined
        ), timeRemaining, true)
      $scope.$apply ->
        if Date.now() - (aic.lang.articles[article].hoveredAt) > 675
          aic.lang.articles[article].hovered = false

    # event handler for clicking rooms
    aic.selectRoom = (room) ->
      if room is 'back'
      else
        # minimise the map, display room info
        aic.vars.minimiseMap = true
        $timeout (->
          aic.vars.selectedRoom = room
        ), (if aic.vars.selectedRoom is 'none' then 1000 else 0), true
      return null

    # modify room settings/options

    aic.adjustRoom = ->

    # turn all the rooms off then on

    aic.rebootRooms = -> aic.mainLoop 'ROOMS', 'rebootRooms'

    ### PLOT FUNCTIONS ###

    # event handler for option selection - effectively maitreyaLoop()

    aic.maitreyaLoop = (conversation, option) ->
      # takes the id of the selected option
      console.log "Maitreya - #{option.bigSection} - #{option.id}"
      delay = 0
      switch conversation
        when 'terminal'
          # this shouldn't happen
          aic.mainLoop option.bigSection, option.id
          # I guess?
        when 'breach'
          delay = writeDialogue(conversation, option.dialogue, 'maitreya', option.id)
          $timeout (->
            breachLoop option.bigSection, option.id
          ), delay * 1000 + aic.maitreyaDelay * 1000
          aic.vars.people[conversation].opinion += option.opinion
        when 'alexandra'
          delay = writeDialogue(conversation, option.dialogue, 'maitreya', option.id)
          $timeout (->
            alexandraLoop option.bigSection, option.id
          ), delay * 1000 + aic.maitreyaDelay * 1000
          aic.vars.people[conversation].opinion += option.opinion
        else
          throw new Error("Conversation #{conversation} does not exist")
      # obviously we don't need the old options anymore
      aic.chatLog[conversation].options = []
      # save to cookie?

    aic.Actor::move = (destination, continuous) ->
      # called when an actor moves from one room to another. they can only move to adjacent rooms
      me = this
      if destination is 'random'
        validRooms = aic.rooms[me.location].connectedTo
        destination = validRooms[Math.floor(Math.random() * validRooms.length)]
      if aic.rooms[me.location].connectedTo.includes(destination)
        me.location = destination
      else
        # we're moving to an invalid room?
        throw new Error("#{me.name} tried to move from #{me.location} to #{destination}")
      me.location

    # alias functions so LoopService can access them
    # TODO make all these on aic anyway
    aic.writeDialogue = writeDialogue
    aic.presentOptions = presentOptions
    aic.breachLoop = breachLoop
    aic.alexandraLoop = alexandraLoop
    aic.endingLoop = endingLoop
    aic.dynamicLoop = dynamicLoop
    aic.preloadAlexandraFaces = preloadAlexandraFaces

    aic.unlock = (target) ->
      if aic.appList.includes(target)
        aic.ready[target] = true
      else if aic.speakerList.includes(target)
        aic.ready[target] = true
      else if target of aic.lang.articles
        aic.lang.articles.target.available = true
      else
        throw new Error("Tried to unlock #{target} which does not exist")
      return null

    aic.lock = (target) ->
      if aic.appList.includes(target)
        aic.ready[target] = false
      else if aic.speakerList.includes(target)
        aic.ready[target] = false
      else if target of aic.lang.articles
        aic.lang.articles.target.available = false
      else
        throw new Error("Tried to lock #{target} which does not exist")
      return null

    aic.eval = eval
    return null

  EncodeURIComponentFilter = ->
    return window.encodeURIComponent

  maitreya = angular
    .module("maitreya", ['ngSanitize', 'ngAnimate'])
    .controller("MaitreyaController",
                ['$scope', '$timeout', '$sce', '$http', MaitreyaController])
    .filter("encode", [EncodeURIComponentFilter])

  return null

# prototype functuon to turn kebab-case to camelCase
String::toCamelCase = ->
  this.toLowerCase()
    .replace(/[^\w\s\-]/g, "")
    .replace(/[^a-z0-9]/g, " ")
    .replace(/^\s+|\s+$/g, "")
    .replace(/\s(.)/g, (match, group) -> group.toUpperCase())

# prototype function to format dialogue strings from wikidot format to HTML

String::wikidot_format = ->
  # pass article argument only if this is an article
  this.replace(/\|\|\|\|/g, "<br>")
    .replace(/\*\*(.*?)\*\*/g, "<b>$1</b>")
    .replace(/\/\/(.*?)\/\//g, "<i>$1</i>")
    .replace(/{{(.*?)}}/g, "<tt>$1</tt>")
    .replace(/\^\^(.*?)\^\^/g, "<sup>$1</sup>")
    # .replace(/\?\?(.*?)\?\?/g, "<span dynamic class=\'statement false\' data-bool=\'TRUE\'>$1</span>")
    # .replace(/!!(.*?)!!/g, "<span class=\'statement true\' data-bool=\'FALSE\'>$1</span>")
    .replace(/^-{3,}$/g, "<hr>")
    .replace(/--/g, "—")
    .replace(/^=\s(.*)$/g, "<div style='text-align: center;'>$1</div>")
    .replace(/(>|^)\!\s([^<]*)/g, "$1<div class='fake-title'>$2</div>")
    .replace(/(>|^)\+{3}\s([^<]*)/g, "$1<h3>$2</h3>")
    .replace(/(>|^)\+{2}\s([^<]*)/g, "$1<h2>$2</h2>")
    .replace(/(>|^)\+{1}\s([^<]*)/g, "$1<h1>$2</h1>")
    .replace(/<([\w\s])|(.*?)>/g, "<span class='$1'>$2</span>")
    .replace(/^\[\[IMAGE\]\]\s([^\s]*)\s(.*)$/g, "<div class=\'scp-image-block block-right\'><img src=\'$1\'><div class=\'scp-image-caption\'><p>$2</p></div></div>")
    .replace /\[{3}(.*?)\|(.*?)\]{3}/, (match, article, text) ->
      # please ready your butts for the single worst line of code I have ever written
      angular.element(document.documentElement).scope().aic.lang.articles[article].available = true
      return "<span class=\'article-link\'>#{text}</span>"
##endregion
