# Description:
#   Trigger custom workflow operations in chat via drush.io.
#
# Dependencies:
#   "@drush-io/api-client": "^1.0.0-alpha.3"
#   "fernet": "^0.3.0"
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
#   hubot drush-io run <job> - Runs a job on the default project.
#   hubot drush-io run <project> job <job> - Runs a job on a given project.
#   hubot drush-io run [<project> job] <job> with <VARIABLE>="<value>" - Runs a job and passes a single variable/value.
#
# Author:
#   iamEAP
#
# Notes:
#   Perfectly functional, but intended more as a base for your own custom
#   commands that suit your custom needs. Probably, you'll want to suppress any
#   need for specific knowledge about project/job names in favor of semantic
#   meaning around what the jobs actually do.
#
#   Recommended that you use this package for API token management, but you can
#   wire up your custom commands by using the robot.drush.io.run() method.

Path = require("path")

Verifiers = require(Path.join(__dirname, "..", "lib", "verifiers"))

TokenForBrain = Verifiers.VaultKey
ApiTokenVerifier = Verifiers.ApiTokenVerifier

module.exports = (robot) ->
  unless process.env.HUBOT_DRUSH_IO_TOKEN_FERNET_SECRETS?
    robot.logger.warning 'The HUBOT_DRUSH_IO_TOKEN_FERNET_SECRETS environment variable is not set. Please set it.'

  class DrushIO
    run: (msg, project, job, vars = {}, waitForResponse = true) ->
      ClientFactory = require "@drush-io/api-client"
      user = robot.brain.userForId msg.envelope.user.id
      token = robot.vault.forUser(user).get(TokenForBrain)
      project = project || process.env.HUBOT_DRUSH_IO_DEFAULT_PROJECT;

      if token
        Client = new ClientFactory(token)
      else
        if process.env.HUBOT_DRUSH_IO_DEFAULT_API_TOKEN
          msg.send "Falling back to a default token because you haven't set your own API token yet. Open a private chat with me and run: drush-io token set <drush_io_api_token>"
          Client = new ClientFactory(process.env.HUBOT_DRUSH_IO_DEFAULT_API_TOKEN)
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

  # hubot drush-io run [<project> job] <job> [with <VAR>="<value>"]
  robot.hear /drush-io run(?: ([a-z0-9\-]+) job)? ([a-z0-9\-]+)(?: with ([a-zA-Z0-9_]+)=\"(.*?)\")?/i, (msg) ->
    payload = {};
    if (msg.match[3] && msg.match[4])
      payload[msg.match[3]] = msg.match[4];

    msg.send "Okay, lemme see what I can do."
    robot.drush.io.run(msg, msg.match[1], msg.match[2], payload).then (result) ->
      if (result.data.status == 'complete')
        msg.send "Looks to have gone smoothly! Here's what I heard back:"
        msg.send result.data.log
      else if (result.data.status == 'error')
        msg.send "There may have been a problem. Here's what I heard back:"
        msg.send result.data.log
