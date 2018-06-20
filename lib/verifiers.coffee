ClientIsh     = require "@ish-cd/api-client"

VaultKey = "hubot-drush-io-secret"

class ApiTokenVerifier
  constructor: (token) ->
    @token = token?.trim()
    @Ish = new ClientIsh(@token)

  valid: (cb) ->
    @Ish.account().get().then (account) ->
      if account.data && account.data.id
        cb(true)
      else
        cb(false)
    .catch () ->
      cb(false)

exports.VaultKey = VaultKey
exports.ApiTokenVerifier = ApiTokenVerifier
