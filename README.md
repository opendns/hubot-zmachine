# hubot-zmachine

Play zmachine with Hubot

See [`src/zmachine.coffee`](src/zmachine.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install hubot-zmachine --save`

Then add **hubot-zmachine** to your `external-scripts.json`:

```json
[
  "hubot-zmachine"
]
```

You will also need an instance of [zmachine-api](https://github.com/opendns/zmachine-api) to connect to.

## Sample Interaction

```
user1>> hubot z look
hubot>> You are standing in an open field west of a white house, with a boarded front door...
```
