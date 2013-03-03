# Heroku Git remote commands

By default, the `heroku` command operates on the application referred to by
the `heroku` Git remote.  This is great for simple apps, but starts to break
down when you need multiple Heroku apps to serve up different environments
(staging, production, and so on).  You end up having to set up a bunch of
remotes by hand, and then your reward is the eternal obligation to explicitly
pass in the remote: `heroku run console -r staging` and the like.  My solution
to this problem is twofold:

1.  Create [binstubs][] for each Heroku app.  For example, in `bin/staging`:

    ```sh
    #!/bin/sh
    HEROKU_APP=myapp-staging exec heroku "$@"
    ```

    Now you can do `staging logs`, `staging info`, and any other Heroku
    command without any `--app` or `--remote` insanity.

2.  Use this plugin, which encapsulates common operations on the Git remote.

## Installation

    $ heroku plugins:install https://github.com/tpope/heroku-remote.git

## Commands

See `heroku help remote` for the complete list.  If you've gone the
[binstubs][] route, you'll want to change `heroku` to the name of your
binstub.

### heroku push

Push to the appropriate Git remote or URL.  You can give any valid `git push`
argument, including the very useful `--force`.  The default is to push
`HEAD` to `master`, effectively deploying the current commit.

If the first argument does not contain a colon, `:master` is appended.  Use
`my-branch:my-branch` if you really want to push something other than a
deployment.

This is aliased as `deploy`, so the instinctive `heroku deploy` works.

### heroku fetch

Fetch the Git remote associated with the given application.  If no Git remote
exists, fetch the repository URL directly, meaning the results will only be
available in `FETCH_HEAD`.

### heroku log

Show a Git log for the currently deployed commit.  Does a `heroku fetch` if
necessary.

    $ heroku log --pretty=oneline

You can also give releases and they will be translated into commit SHAs.

    $ heroku log v123..v124

Not to be confused with `heroku logs`.

### heroku checkout

Check out the currently deployed release commit.  Does a `heroku fetch` if
necessary.  Accepts an optional release to check out instead.

    $ heroku checkout -b still-working v122

### heroku remote:add

Adds the application as a Git remote named after itself.  This is useful if
you need to break out of the box offered by the above commands.

    $ heroku remote:add --app myapp-staging

Normally you would use this with [binstubs][]:

    $ staging remote:add

[binstubs]: https://github.com/sstephenson/rbenv/wiki/Understanding-binstubs

## License

Copyright © Tim Pope.  MIT License.  See LICENSE for details.
