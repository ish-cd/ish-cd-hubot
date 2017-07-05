DrushIOClient     = require "@drush-io/api-client"

VaultKey = "hubot-drush-io-secret"

class ApiTokenVerifier
  constructor: (token) ->
    @token = token?.trim()
    @DrushIO = new DrushIOClient(@token)

  valid: (cb) ->
    @DrushIO.account().get().then (account) ->
      if account.data && account.data.id
        cb(true)
      else
        cb(false)
    .catch () ->
      cb(false)

exports.VaultKey = VaultKey
exports.ApiTokenVerifier = ApiTokenVerifier
