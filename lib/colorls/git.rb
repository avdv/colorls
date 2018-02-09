module ColorLS
  class Git < Core
    def self.status(repo_path)
      @git_status = {}

      call_git('-C', repo_path, 'status', '--porcelain', '-z', '--ignored', '-uno') do |mode, file|
        @git_status[file] = mode if mode == '??'
      end

      call_git('-C', repo_path, 'status', '--porcelain', '-z', '-unormal') do |mode, file|
        @git_status[file] = mode
      end

      @git_status
    end

    def self.colored_status_symbols(modes, colors)
      modes =
        case modes.length
        when 1 then "  #{modes} "
        when 2 then " #{modes} "
        when 3 then "#{modes} "
        when 4 then modes
        end

      modes
        .gsub('?', '?'.colorize(colors[:untracked]))
        .gsub('A', 'A'.colorize(colors[:addition]))
        .gsub('M', 'M'.colorize(colors[:modification]))
        .gsub('D', 'D'.colorize(colors[:deletion]))
        .tr('!', ' ')
    end

    private_class_method def self.call_git(*args)
      IO.popen(['git'] + args) do |output|
        output.read.split("\x0").each { |x| yield x.split(' ', 2) }
      end
      warn "git status failed in #{repo_path}" unless $CHILD_STATUS.success?
    end
  end
end
