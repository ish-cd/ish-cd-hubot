# hubot-drush-io

Base package for triggering drush.io jobs via Hubot. Features include:

- Encrypted storage for drush.io API Tokens in Hubot's brain
- Basic command run support
- API for running commands 

See [`src/drush-io.coffee`](src/drush-io.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install @drush-io/hubot-drush-io --save`

Then add **@drush-io/hubot-drush-io** to your `external-scripts.json`:

```json
["@drush-io/hubot-drush-io"]
```

## Configuration

- `HUBOT_DRUSH_IO_TOKEN_FERNET_SECRETS` - The key used for encrypting your
  tokens in the hubot's brain. A comma delimited set of different key tokens.
  To create one run `dd if=/dev/urandom bs=32 count=1 2>/dev/null | openssl base64`
  on a UNIX system.
- `HUBOT_DRUSH_IO_DEFAULT_API_TOKEN` - Optional. A drush.io API token that, if
  set, is used when a user with no API token set attempts to run a drush.io job.
  Only set this if you need to.

## API

This package adds functionality to `robot` that allows you to easily build
custom commands that trigger drush.io jobs:

```coffeescript
# Listen for the phrase "deploy to test"
robot.hear /^deploy to test$/i, (msg) ->
  # Trigger the "deployt-to-test" job on "my-project"
  robot.drush.io.run(msg, 'my-project', 'deploy-to-test').then (result) ->
    msg.send result.data.log
```

The function signature for `robot.drush.io.run` is like so:

```javascript
/**
 * Triggers a job run for a given project on drush.io using the user on the
 * provided msg.
 * 
 * @param msg
 *   The res/msg object that is provided as the first argument to robot.hear's
 *   callback. Used to determine the user and retrieve their token.
 * 
 * @param {String} project
 *   The machine name (or ID) of the drush.io project associated with the job
 *   you wish to run.
 * 
 * @param {String} job
 *   The machine name (or ID) of the drush.io job you wish to run.
 *
 * @param {Object} vars
 *   An optional key/value pair of variables to send as context for your job
 *   run. Defaults to an empty object.
 *
 * @param {Boolean} waitForResponse
 *   An optional boolean indicating whether the run should be synchronous
 *   (meaning, wait completely for the job run to execute so that the run's log
 *   can be read and/or printed), or asynchronous (meaning, don't wait for
 *   job execution, just wait for it to be queued). Defaults to true.
 *   
 * @return Promise
 *   If waitForResponse is true, this will resolve with the executed job run
 *   once complete. If waitForResponse is false, this will resolve as soon as
 *   the job run is successfully queued.
 */
function run(msg, project, job, vars, waitForResponse) {}
```

## Notes

Most of this code was extracted from [hubot-gh-token](https://github.com/hubot-scripts/hubot-gh-token)
, which uses code from [hubot-deploy](https://github.com/atmos/hubot-deploy),
which uses code from [hubot-vault](https://github.com/ys/hubot-vault).

This script is similar to
[hubot-github-identity](https://github.com/tombell/hubot-github-identity) but
allows users to set  tokens in chat instead of through Hubot's http listener.

## Sample Interaction

```
user1>> bot drush.io token set eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.t-IDcSemACt8x4iTMCda8Yhe3iZaWbvV5XKSTbuAn0M
bot>> Your drush.io  API token is valid. I stored it for future use.
user1>> bot drush.io token verify
bot>> Your drush.io API token is valid on api.github.com.
user1>> bot drush.io token reset
bot>> I nuked your drush.io API token. You may not be able to run drush.io jobs until you set another token.
```
