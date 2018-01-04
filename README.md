# SMSForwarder

A daemon to bridge a [VoIP.ms](https://voip.ms) account's SMS sending and receiving capabilities into a Slack team.

## Architectural Motivation

It is impossible to use Slack's current API to automatically create new users in a team. A single "bot" user can be made per app connected to the team, and this bot user can simulate different visual avatars within chat messages, but these messages' senders are all technically the one bot user. The bot user has only one inbound DM channel, etc. This means that you cannot have separate virtual users per conversation.

Instead, right now, the daemon creates a new *public channel* for each inbound SMS sender, named after their DID number. The one bot user representing the forwarder then joins all such channels and posts all relevant inbound messages as itself. The bot user then listens for messages on these channels; any message posted to such a DID-named channel by a *non-bot user* (i.e. by a person logged into the Slack team) is converted by the forwarder into an outbound SMS message back to the DID the channel is named after.

Right now, the daemon makes a few bad assumptions:

* that the Slack team it is connected to is entirely dedicated to the purpose of being an SMS call center. It does not expect to see channels within the team that it did not create itself. I haven't verified what happens in this case.

* that there is exactly one human user account in the Slack team. This one user is automatically invited by the daemon into each new DID channel as it is created. Other users would have to join each channel manually.

## Installation

SMSForwarder's only requirement to build is Elixir. The codebase is primarily used as a Heroku app, so deploying it on Heroku using the Elixir buildpack (https://github.com/HashNuke/heroku-buildpack-elixir.git) is a first-class supported use-case.

SMSForwarder is configured entirely using environment variables:

* `BASE_URI`: the public-routable URL of your deployment (e.g. `https://foo.herokuapp.com`)
* `SLACK_BOT_API_TOKEN`: an API token created by registering a new Slack app
* `SLACK_USER_API_TOKEN`: an API token created using the Slack [legacy token generator](https://api.slack.com/custom-integrations/legacy-tokens), allowing control of the human responder-user's account (to manage automatic channel joins)
* `VOIPMS_CREDENTIALS`: your VoIP.ms API credentials, in the format `email:api_password:account_id`
* `VOIPMS_DID`: the DID in your VoIP.ms account which you want to be used for *sending* messages. Should be in 10-digit format, e.g. `5551234567`
* `REDIS_URL` (optional): a Redis instance to hold DID nickname mappings (used by the bot user)
* `TWILIO_CREDENTIALS` (optional): a Twilio API token—used for sending outbound MMS attachments
