# Heroku Git remote commands

By default, the `heroku` command operates on the application referred to by
the `heroku` Git remote.  This is great for simple apps, but starts to break
down when you need multiple Heroku apps to serve up different environments
(staging, production, and so on).  You end up having to set up a bunch of
remotes by hand, and then your reward is the eternal obligation to explicitly
pass in the remote: `heroku run console -r staging` and the like.  My solution
to this problem is twofold:

1.  [Create a binstub for each Heroku app][binstubs].

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

### heroku sha

Show the commit SHA for the currently deployed or given release.  Useful if
you need to break out of the box offered by the built-ins.

    $ git cherry -v $(heroku sha)
    $ git log $(staging sha)...$(production sha)

### heroku remote:add

Adds the application as a Git remote named after itself.  Useful if you've
been using [binstubs][] with no remote.

    $ staging remote:add

### heroku remote:setup

Create a `heroku` remote for an app named after the current directory, and one
remote for each app named like `directory-*`, named after the `*` portion.
Override the name of the `heroku` remote with `-r`.  Here's my recommended
setup, which pairs perfectly with [heroku binstubs][binstubs]:

    $ heroku remote:setup -r production

[binstubs]: https://github.com/tpope/heroku-binstubs

## License

Copyright © Tim Pope.  MIT License.  See LICENSE for details.
