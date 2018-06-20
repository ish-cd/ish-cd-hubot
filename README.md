# hubot-ish-cd

Base package for triggering Ish CD jobs via Hubot. Features include:

- Encrypted storage for Ish CD API Tokens in Hubot's brain
- Job running and list support
- API for running commands in your custom Hubot scripts

See [`src/ish-cd.coffee`](src/ish-cd.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install @ish-cd/hubot-ish-cd --save`

Then add **@ish-cd/hubot-ish-cd** to your `external-scripts.json`:

```json
["@ish-cd/hubot-ish-cd"]
```

## Configuration

- `HUBOT_ISH_CD_TOKEN_FERNET_SECRETS` - The key used for encrypting your
  tokens in the Hubot's brain. A comma delimited set of different key tokens.
  To create one run `dd if=/dev/urandom bs=32 count=1 2>/dev/null | openssl base64`
  on a UNIX system.
- `HUBOT_ISH_CD_DEFAULT_PROJECT` - Optional. An ISH CD project-ish (project
  ID or project machine name) that will be used when running jobs if no project
  is provided. Recommended unless you use multiple/many Ish CD projects.
- `HUBOT_ISH_CD_DEFAULT_API_TOKEN` - Optional. An ISH CD API token that, if
  set, is used when a user with no API token set attempts to run an Ish CD job.
  Only set this if you need to.

## Usage

For complete and up-to-date usage details, type the following in your chat
client `hubot help ish` and check the "Sample Interaction" section
below.

Common commands include:
- `hubot ish set token {Ish CD api token}` - Intended for private chat
  with the bot, this command stores a user's Ish CD API token in Hubot's
  brain (encrypted) so that jobs run by the user leverage the user's Ish CD
  credentials and permissions.
- `hubot ish list jobs` - Shows a list of jobs that can be run.
- `hubot ish run job {job name}` - Runs a job. If the job includes
  required or optional variables, Hubot will ask for those details.

## API

This package adds functionality to `robot` that allows you to easily build
custom commands that trigger Ish CD jobs:

```coffeescript
# Listen for the phrase "deploy to test"
robot.hear /^deploy to test$/i, (msg) ->
  # Trigger the "deploy-to-test" job on "my-project"
  robot.ish.run(msg, 'my-project', 'deploy-to-test').then (result) ->
    msg.send result.data.log
```

The function signature for `robot.ish.run` is like so:

```javascript
/**
 * Triggers a job run for a given project on Ish CD using the user on the
 * provided msg.
 * 
 * @param msg
 *   The res/msg object that is provided as the first argument to robot.hear's
 *   callback. Used to determine the user and retrieve their token.
 * 
 * @param {String} project
 *   The machine name (or ID) of the Ish CD project associated with the job
 *   you wish to run. If none is provided (null), the value of the environment
 *   variable HUBOT_ISH_CD_DEFAULT_PROJECT will be used.
 * 
 * @param {String} job
 *   The machine name (or ID) of the ISH CD job you wish to run.
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
allows users to set tokens in chat instead of through Hubot's http listener.

## Sample Interaction

```
user1>> hubot ish token set eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.t-IDcSemACt8x4iTMCda8Yhe3iZaWbvV5XKSTbuAn0M
hubot>> Your Ish CD API token is valid. I stored it for future use.
user1>> hubot ish token verify
hubot>> Your Ish CD API token is valid.
user1>> hubot ish list jobs
hubot>> Create Multidev (create-multidev)
        Deploy to Prod (deploy-to-prod)
user1>> hubot ish run create-multidev
hubot>> What should MULTIDEV_NAME be set to?
user1>> my-feat
hubot>> Okay, lemme see what I can do.
hubot>> Looks to have gone smoothly! Here's what I heard back:
hubot>> ................................
        [2017-10-05 20:04:07] [info] Created Multidev environment "my-feat"
user1>> hubot ish token reset
hubot>> I nuked your Ish CD API token. You may not be able to run Ish CD jobs until you set another token.
```
