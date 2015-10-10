# Description
#   Play zmachine with Hubot
#
# Configuration:
#   HUBOT_ZMACHINE_SERVER - A zmachine-api server.
#   HUBOT_ZMACHINE_ROOMS - Optional. A comma-delimited list of rooms that don't require prefixes; all text will be zmachineed.
#   HUBOT_ZMACHINE_OT_PREFIX - Optional. If you've got an on-topic room, use this text as prefix for off-topic talk.
#
# Commands:
#   hubot z list - Lists all in-progress games on a server (also syncs hubot with server)
#   hubot z start <game> - Starts a game (default is 'zmachine1')
#   hubot z <action> - Performs the action
#   hubot z save <name> - Saves a game with the given name via the zmachine-api (you can save via an action, but that will only save a local copy)
#   hubot z restore <name> - Loads a game with the given name via the zmachine-api
#   hubot z stop - Ends the game for this channel
#   hubot z purge - Purges all in-progress games from memory (to be re-synced)
#
# Notes:
#   For fun and whimsy!
#
# Author:
#   Justin Swift <jswift@opendns.com>

# Shamelessly stolen snippets
String::startsWith ?= (s) -> @[...s.length] is s

module.exports = (robot) ->
  unless process.env.HUBOT_ZMACHINE_SERVER
    robot.logger.error "HUBOT_ZMACHINE_SERVER not defined, cannot play zmachine!"
    return
  server = process.env.HUBOT_ZMACHINE_SERVER

  if process.env.HUBOT_ZMACHINE_ROOMS
    zmachineRooms = process.env.HUBOT_ZMACHINE_ROOMS.split(',')
    robot.logger.debug "Playing on-topic zmachine in #{zmachineRooms}"
  else
    robot.logger.debug "No on-topic zmachine rooms"
    zmachineRooms = []

  if process.env.HUBOT_ZMACHINE_OT_PREFIX
    offtopicPrefix = process.env.HUBOT_ZMACHINE_OT_PREFIX
  else
    offtopicPrefix = "#"

  zmachinePids = {}
  initialized = false

  get_key = (msg) ->
    if msg.message.user.room?
      return msg.message.user.room
    else
      return msg.message.user.name

  list_games = (msg, callback, args) ->
    msg.http("#{server}/games")
      .get() (err, res, body) ->
        if err
          msg.send "Error: #{err}"
          return
        else
          bodyJ = JSON.parse(body)
          zmachinePids = {}
          zmachinePids[bodyJI.label] = bodyJI.pid for bodyJI in bodyJ
          initialized = true
          if callback?
            callback msg, args
            robot.logger.debug "Initialized: #{body}"
          else
            msg.send "Initialized: #{body}"

  purge_list = (msg) ->
    zmachinePids = {}

  start_game = (msg, game) ->
    # Make sure we don't already have a room going
    key = get_key msg
    if zmachinePids[key]?
      msg.send "There's already a game for #{key}!"
      return

    # Start the game
    msg.send "Starting game"
    game = game
    label = key
    data = "game=#{game}&label=#{label}"
    msg.http("#{server}/games")
      .header('Content-Type', 'application/x-www-form-urlencoded')
      .post(data) (err, res, body) ->
        if err
          msg.send "Error: #{err}"
          return
         else
           bodyJ = JSON.parse(body)
           pid = bodyJ.pid
           zmachinePids[key] = pid
           msg.send "Started game #{pid}"
           msg.send bodyJ.data

  stop_game = (msg) ->
    key = get_key msg
    if zmachinePids[key]?
      pid = zmachinePids[key]
      msg.send "Killing game #{key}"
      msg.http("#{server}/games/#{pid}")
        .delete() (err, res, body) ->
          if err
            msg.send "Error: #{err}"
            return
          else
             msg.send body
             list_games msg

  do_action = (msg, action) ->
    # Make sure we have a room going
    key = get_key msg
    if not zmachinePids[key]
      msg.send "There's no game for #{key}!"
      return

    # Do the action
    robot.logger.debug "Doing action: #{action}"
    data = "action=#{action}"
    pid = zmachinePids[key]
    msg.http("#{server}/games/#{pid}/action")
      .header('Content-Type', 'application/x-www-form-urlencoded')
      .post(data) (err, res, body) ->
        if err
          msg.send "Error: #{err}"
          return
        else
          try
            bodyJ = JSON.parse(body)
            msg.send bodyJ.data
          catch
            msg.send "Received non-JSON response:"
            msg.send body

  save_game = (msg, name) ->
    # Make sure we have a room going
    key = get_key msg
    if not zmachinePids[key]
      msg.send "There's no game for #{key}!"
      return

    # Start the game
    msg.send "Saving game"
    name = name
    pid = zmachinePids[key]
    data = "file=#{name}"
    msg.http("#{server}/games/#{pid}/save")
      .header('Content-Type', 'application/x-www-form-urlencoded')
      .post(data) (err, res, body) ->
        if err
          msg.send "Error: #{err}"
          return
         else
          try
            bodyJ = JSON.parse(body)
            msg.send bodyJ.data
          catch
            msg.send "Received non-JSON response:"
            msg.send body

  restore_game = (msg, name) ->
    # Make sure we have a room going
    key = get_key msg
    if not zmachinePids[key]
      msg.send "There's no game for #{key}!  Start the game you want to restore first!"
      return

    # Restore the game
    msg.send "Restoring game"
    name = name
    pid = zmachinePids[key]
    data = "file=#{name}"
    msg.http("#{server}/games/#{pid}/restore")
      .header('Content-Type', 'application/x-www-form-urlencoded')
      .post(data) (err, res, body) ->
        if err
          msg.send "Error: #{err}"
          return
         else
          try
            bodyJ = JSON.parse(body)
            msg.send bodyJ.data
          catch
            msg.send "Received non-JSON response:"
            msg.send body

  process_zmachine_msg = (msg) ->
    action = msg.match[1]
    robot.logger.debug "User #{msg.message.user.name} in room #{msg.message.user.room} doing: #{action}"

    if action.startsWith("start")
      # Default to zmachine1, a classic
      game = "zmachine1"
      actionList = action.split " "
      if actionList.length > 1
        # Try whatever game the user specified
        game = actionList[1]
      start_game msg, game
    else if action == "stop"
      # End the game
      stop_game msg
    else if action == "list"
      # List all in-progress games on the server (and sync with them)
      list_games msg
    else if action == "purge"
      # Forget all in-progress games; use when you need to re-sync with the server
      purge_list msg
    else if action.startsWith("save")
      # Save to cloud
      name = "save"
      actionList = action.split " "
      if actionList.length > 1
        # Try whatever game the user specified
        name = actionList[1]
      save_game msg, name
    else if action.startsWith("restore")
      # Restore from cloud
      name = "save"
      actionList = action.split " "
      if actionList.length > 1
        # Try whatever game the user specified
        name = actionList[1]
      restore_game msg, name
    else
      # Not a special command, so Just zmachine It
      do_action msg, action


  # For in-character rooms, hear/respond to everything
  robot.hear /(.*)/i, (msg) ->
    if not msg.message.user.room?
      # Private messages always require direct zmachine-ing
      return
    if msg.message.user.room not in zmachineRooms
      # If we're not in a direct room, do nothing
      return

    action = msg.match[1]

    if action.startsWith("/me") or action.startsWith(offtopicPrefix)
      # ignore actions and the offtopicPrefix
      return

    if action.startsWith(robot.name)
      # If we're in a direct room, and we hear the robot name, ignore and let respond handle it
      return

    robot.logger.debug "User #{msg.message.user.name} in room #{msg.message.user.room} doing: #{action}"
    if not initialized
      list_games msg, do_action, action
    else
      do_action msg, action

  # For all rooms, respond directly to "z " commands
  robot.respond /(?:z)(?: me)? (.*)/i, (msg) ->
    if not initialized
      # If we've just come up, we should sync our list of on-going games
      list_games msg, process_zmachine_msg
    else
      process_zmachine_msg msg
