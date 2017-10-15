# Description:
#   Trigger custom workflow operations in chat via drush.io.
#
# Dependencies:
#   "@drush-io/api-client": "^1.0.0-alpha.3"
#   "fernet": "^0.3.0"
#   "hubot-conversation": "^1.1.1"
#
# Configuration:
#   HUBOT_DRUSH_IO_TOKEN_FERNET_SECRETS - The key used for encrypting your tokens in the hubot's brain. See README for details.
#   HUBOT_DRUSH_IO_DEFAULT_PROJECT - A default project-ish (ID or name) that, if set, is used when running jobs. See README for details.
#   HUBOT_DRUSH_IO_DEFAULT_API_TOKEN - A default API token (unencrypted) that, if set, is used when a user with no token set triggers a job.
#
# Commands:
#   hubot drush-io token set <drush_io_api_token> - Set your user's drush.io API token (USE THIS ONLY IN A PRIVATE CHAT WITH THE BOT)
#   hubot drush-io token reset - Resets (forgets) your user's drush.io API token
#   hubot drush-io token verify - Verifies your drush.io token is valid
#   hubot drush-io list jobs - Lists available jobs to run on the default project.
#   hubot drush-io list jobs for <project> - Lists available jobs on the given project.
#   hubot drush-io run <job> - Runs a job on the default project.
#   hubot drush-io run <project> job <job> - Runs a job on a given project.
#
# Author:
#   iamEAP
#
# Notes:
#   This package also introduces an API you can use to write a custom hubot
#   script that can trigger drush.io jobs. Check the README for details.

Path = require("path")
Conversation = require("hubot-conversation")

Verifiers = require(Path.join(__dirname, "..", "lib", "verifiers"))

TokenForBrain = Verifiers.VaultKey
ApiTokenVerifier = Verifiers.ApiTokenVerifier

module.exports = (robot) ->
  switchBoard = new Conversation(robot);

  unless process.env.HUBOT_DRUSH_IO_TOKEN_FERNET_SECRETS?
    robot.logger.warning 'The HUBOT_DRUSH_IO_TOKEN_FERNET_SECRETS environment variable is not set. Please set it.'

  class DrushIO
    _getClient: (msg) ->
      ClientFactory = require "@drush-io/api-client"
      user = robot.brain.userForId msg.envelope.user.id
      token = robot.vault.forUser(user).get(TokenForBrain)
      if token
        return new ClientFactory(token)
      else if process.env.HUBOT_DRUSH_IO_DEFAULT_API_TOKEN
        return new ClientFactory(process.env.HUBOT_DRUSH_IO_DEFAULT_API_TOKEN)
      else
        return null

    run: (msg, project, job, vars = {}, waitForResponse = true) ->
      Client = this._getClient msg
      user = robot.brain.userForId msg.envelope.user.id
      hasToken = !! robot.vault.forUser(user).get(TokenForBrain)
      project = project || process.env.HUBOT_DRUSH_IO_DEFAULT_PROJECT;

      if !hasToken
        if process.env.HUBOT_DRUSH_IO_DEFAULT_API_TOKEN
          msg.send "Falling back to a default token because you haven't set your own API token yet. Open a private chat with me and run: drush-io token set <drush_io_api_token>"
        else
          msg.send "You can't run jobs until you set an API token. Open a private chat with me and run: drush-io token set <drush_io_api_token>"
          return Promise.reject()

      return Client.projects(project).jobs(job).runs().create({env: vars}, waitForResponse)


  robot.drush = {
    io: new DrushIO
  };

  # hubot drush-io token set <token>
  robot.respond /drush-io token set ([a-zA-Z0-9-_]+\.[a-zA-Z0-9-_]+\.[a-zA-Z0-9-_]+[\/a-zA-Z0-9-_]+)$/i, id: 'drush-io-token.set', (msg) ->
    user = robot.brain.userForId msg.envelope.user.id
    token = msg.match[1]

    verifier = new ApiTokenVerifier token
    verifier.valid (result) ->
      if result
        robot.vault.forUser(user).set(TokenForBrain, verifier.token)
        msg.send "Your drush.io API token is valid. I stored it for future use."
      else
        msg.send "Your drush.io API token is invalid. Try regenerating and setting it again."

  # hubot drush-io token reset
  robot.respond /drush-io token reset$/i, id: 'drush-io-token.reset', (msg) ->
    user = robot.brain.userForId msg.envelope.user.id
    robot.vault.forUser(user).unset(TokenForBrain)
    msg.reply "I nuked your drush.io API token. You may not be able to run drush.io jobs until you set another token."

  # hubot drush-io token verify
  robot.respond /drush-io token verify$/i, id: 'drush-io-token.verify', (msg) ->
    user = robot.brain.userForId msg.envelope.user.id
    token = robot.vault.forUser(user).get(TokenForBrain)
    verifier = new ApiTokenVerifier(token)
    verifier.valid (result) ->
      if result
        msg.send "Your drush.io API token is valid."
      else
        msg.send "Your drush.io token is invalid. Try regenerating and setting it again."

  # hubot drush-io list jobs [for <project>]
  robot.hear /drush-io list jobs(?: for ([a-z0-9\-]+))?/i, (msg) ->
    Client = robot.drush.io._getClient(msg);
    project = msg.match[1] || process.env.HUBOT_DRUSH_IO_DEFAULT_PROJECT;

    unless Client?
      return

    Client.projects(project).jobs().list().then (jobs) ->
      msg.send jobs.map (job) ->
        "#{job.data.label} (#{job.data.name})"
      .join "\n"

  # hubot drush-io run [<project> job] <job>
  robot.hear /drush-io run(?: ([a-z0-9\-]+) job)? ([a-z0-9\-]+)/i, (msg) ->
    Client = robot.drush.io._getClient(msg);
    project = msg.match[1] || process.env.HUBOT_DRUSH_IO_DEFAULT_PROJECT;
    payload = {};

    unless Client?
      return

    # Load job metadata, determine if this job has requisite dependencies.
    Client.projects(project).jobs(msg.match[2]).get().then (job) ->
      # If so, begin a dialog with the user to get these dependencies.
      if job.data.dependencies && job.data.dependencies.env
        reqs = for envVar, requirement of job.data.dependencies.env
          envVar

        dialog = switchBoard.startDialog(msg, 10000);

        # Utility, recursive function for getting all job dependencies.
        addQuestionToDialog = (remainingVars) ->
          return new Promise (resolve, reject) ->
            isOptional = job.data.dependencies.env[remainingVars[0]] == 'optional'

            # If the user is idle for too long, abort the request.
            dialog.dialogTimeout = () ->
              reject("Cancelling your #{msg.match[2]} run request.")

            # Ask for environment variable values.
            msg.reply "What should #{remainingVars[0]} be set to? "
            if isOptional
              msg.reply "Enter (default) to use default value."

            # Listen for responses and add them to the payload.
            dialog.addChoice(/(.*?)/i, (responseMsg) ->
              payload[remainingVars[0]] = responseMsg.message.text
              if isOptional && responseMsg.message.text == '(default)'
                delete payload[remainingVars[0]]

              # If there are more dependencies to get, recurse.
              remainingVars.shift()
              if remainingVars.length
                addQuestionToDialog(remainingVars).then(resolve).catch(reject)
              else
                resolve()
            )

        # Iterate through the dialog to get job dependencies from the user.
        return addQuestionToDialog(reqs).catch (rejectionMessage) ->
          msg.reply rejectionMessage
          return Promise.reject()
      else
        return Promise.resolve()

    .then () ->
      msg.send "Okay, lemme see what I can do."
      robot.drush.io.run(msg, msg.match[1], msg.match[2], payload).then (result) ->
        if (result.data.status == 'complete')
          msg.send "Looks to have gone smoothly! Here's what I heard back:"
          msg.send result.data.log
        else if (result.data.status == 'error')
          msg.send "There may have been a problem. Here's what I heard back:"
          msg.send result.data.log
