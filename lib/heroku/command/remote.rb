# work with the remote repository
class Heroku::Command::Remote < Heroku::Command::Base

  # remote
  #
  # show the Git remote name or Git URL for the app
  def index
    display(remote_name || git_url)
  end

  # remote:url
  #
  # show the Git URL for the app
  def url
    display(git_url)
  end

  # remote:name
  #
  # show the name of the Git remote for the app
  def name
    if remote_name
      display(remote_name)
    else
      error("No remote for application #{app}")
    end
  end

  # sha [RELEASE]
  #
  # show the commit SHA for the given or latest release
  #
  # If the commit is locally available, shows the full 40 digits.  Otherwise
  # just shows the 7 we get back from the API.
  def sha
    commit = fetch_release_commit(shift_argument)
    sha = git("rev-parse --quiet --verify #{commit}")
    if sha.empty?
      display(commit)
      exit 1
    else
      display(sha)
    end
  end
  alias_command 'sha', 'remote:sha'

  # remote:add [NAME]
  #
  # add a remote for the app
  #
  # If NAME is not specified, it defaults to the same name as the app itself.
  def add
    create_git_remote(shift_argument || app, git_url)
  end

  # remote:setup [BASENAME]
  #
  # add remotes for a family of apps
  #
  # Add remotes for BASENAME and BASENAME-*.  BASENAME defaults to the
  # repository directory name.
  #
  # -f, --full          # use full app name
  # -r, --remote REMOTE # name for BASENAME (not BASENAME-*) remote
  #
  #Examples:
  #
  # ~/foo $ heroku remote:setup
  # Git remote heroku added
  # Git remote staging added
  #
  # ~/foo $ heroku remote:setup -f
  # Git remote foo added
  # Git remote foo-staging added
  #
  # ~/foo $ heroku remote:setup -r production
  # Git remote production added
  # Git remote staging added
  def setup
    original = shift_argument || File.basename(Dir.pwd).tr('_', '-').split('.').first
    apps = []
    basename = [original, original.gsub(/-/, '')].detect do |b|
      apps = get_apps.select {|a| a['name'] =~ /^#{b}(-|$)/}
      apps.any?
    end
    if apps.empty?
      error("Couldn't find any apps named #{original} or #{original}-*.")
    end
    apps.each do |app|
      remote =
        if options[:remote] && app['name'] == basename
          options[:remote]
        elsif options[:full]
          app['name']
        else
          app['name'][basename.length+1..-1] || 'heroku'
        end
      if git('remote').split("\n").include?(remote)
        display "Git remote #{remote} already exists"
      else
        create_git_remote(remote, app['git_url'])
      end
    end
  end

  # push [REFSPEC ...]
  #
  # git push the given REFSPEC to the app remote
  #
  # If REFSPEC is not specified, it defaults to HEAD:master.  If it is
  # specified but does not contain a colon, :master will be appended.
  #
  # -f, --force   # force push
  # -n, --dry-run # don't actually send the updates
  def push
    refspec = (args.shift || 'HEAD').dup
    refspec << ':master' unless refspec.include?(':') || refspec =~ /^-/
    args.unshift('--force') if options[:force]
    args.unshift('--dry-run') if options[:dry_run]
    arguments = ['git', 'push', remote_name || git_url, refspec] + args
    puts arguments.join(" ")
    system(*arguments)
  end
  alias_command "push", "remote:push"
  # If someone has a more elaborate "deploy" command, let it take precedence.
  unless Heroku::Command.command_aliases['deploy']
    alias_command "deploy", "remote:push"
  end

  # fetch [REFSPEC ...]
  #
  # git fetch from the app Git remote
  #
  # If a Git remote exists for the application, fetch that remote.  Otherwise,
  # fetch the underlying repository URL, leaving the results only in
  # FETCH_HEAD.
  def fetch
    arguments = ['git', 'fetch', remote_name || git_url] + args
    puts arguments.join(" ")
    system(*arguments)
  end
  alias_command 'fetch', 'remote:fetch'

  # log [...]
  #
  # invoke git log on a release commit
  #
  # Translates any arguments that look like releases (v followed by digits) to
  # SHAs and invoke git log.  If no releases appear in the argument list, the
  # latest release is added.
  #
  # Not to be confused with the server logs command "logs".
  #
  #Examples:
  #
  # $ heroku log -p
  # $ heroku log v101
  # $ heroku log v102..v103
  def log
    found = false
    arguments = args.map do |arg|
      case arg
      when /^-/, '..', '...'
        arg
      when /^(.*?)(\.{2,3})(.*)$/
        found = true
        "#{fetch_release_commit($1)}#$2#{fetch_release_commit($3)}"
      when /^(v\d+)$/
        found = true
        fetch_release_commit(arg)
      else
        arg
      end
    end
    arguments.unshift(fetch_release_commit) unless found
    system('git', 'log', *arguments)
  end
  alias_command 'log', 'remote:log'

  # checkout [RELEASE] [...]
  #
  # invoke git checkout on a release commit
  #
  # Defaults to the latest release.
  #
  #Examples:
  #
  # $ heroku checkout
  # $ heroku checkout -b not_broken v123
  def checkout
    release = nil
    args.delete_if do |arg|
      if !release && arg =~ /^v\d+$/
        release = arg
      end
    end
    system('git', 'checkout', fetch_release_commit(release), *args)
  end
  alias_command 'checkout', 'remote:checkout'

  private

  def platform_api
    @platform_api ||=
      begin
        require 'platform-api'
        PlatformAPI.connect(Heroku::Auth.password)
      rescue LoadError
      end
  end

  def get_apps
    if platform_api
      platform_api.app.list
    else
      api.get_apps.body
    end
  end

  def get_app(app_name = app)
    if platform_api
      begin
        platform_api.app.info(app_name)
      rescue Excon::Error::NotFound
        error "App not found"
      end
    else
      api.get_app(app_name).body
    end
  end

  def remote_name
    @remote_name ||= (git_remotes(Dir.pwd) || {}).invert[app]
  end

  def git_url
    @git_url ||= get_app['git_url']
  end

  def fetch_commit(sha)
    if git("rev-parse --quiet --verify #{sha}").empty?
      unless @fetched
        git("fetch #{remote_name || git_url}")
        @fetched = true
      end
    end
    sha
  end

  def get_release_commit(release_name = nil)
    if platform_api
      release =
        if release_name.to_s.empty?
          platform_api.release.list(app).last
        else
          platform_api.release.info(app, release_name)
        end
      platform_api.slug.info(app, release['slug']['id'])
    else
      if release_name.to_s.empty?
        api.get_releases(app).body.last
      else
        api.get_release(app, release_name).body
      end
    end['commit']
  end


  def fetch_release_commit(release = nil)
    if release.to_s.empty? || release =~ /^v\d+$/
      fetch_commit(get_release_commit(release))
    else
      release
    end
  end

  def system(*)
    super or exit($?.exitstatus.to_i)
  end

end
