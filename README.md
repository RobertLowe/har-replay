# har-replay

A *very* basic implementation to replay HAR (http archive) files with Crystal

# How to use this:

- Clone the repository
- `shards install`
- Change replay.har to what you want to replay
- Run `crystal replay.cr`

to change conncurency:

- Run `SPAWN=10 crystal replay.cr`

And unleash hell.
