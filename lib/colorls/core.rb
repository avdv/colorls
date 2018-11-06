# coding: utf-8
module ColorLS
  class Core
    def initialize(input, all: false, report: false, sort: false, show: false,
      mode: nil, git_status: false, almost_all: false, colors: [], group: nil,
      reverse: false, hyperlink: false)
      @input        = File.absolute_path(input)
      @count        = {folders: 0, recognized_files: 0, unrecognized_files: 0}
      @all          = all
      @almost_all   = almost_all
      @hyperlink    = hyperlink
      @report       = report
      @sort         = sort
      @reverse      = reverse
      @group        = group
      @show         = show
      @one_per_line = mode == :one_per_line
      @long         = mode == :long
      @tree         = mode == :tree
      @horizontal   = mode == :horizontal
      process_git_status_details(git_status)

      @screen_width = IO.console.winsize[1]
      @screen_width = 80 if @screen_width.zero?

      init_colors colors

      @contents   = init_contents(input)
      init_icons
    end

    def ls
      return print "\n   Nothing to show here\n".colorize(@colors[:empty]) if @contents.empty?

      layout = case
               when @tree then
                 print "\n"
                 return tree_traverse(@input, 0, 2)
               when @horizontal then
                 HorizontalLayout.new(@contents, @screen_width)
               when @one_per_line || @long then
                 HorizontalLayout.new(@contents, 1)
               else
                 VerticalLayout.new(@contents, @screen_width)
               end

      layout.each_line do |line, widths|
        ls_line(line, widths)
      end

      display_report if @report
      true
    end

    private

    def init_colors(colors)
      @colors  = colors
      @modes = Hash.new do |hash, key|
        color = case key
                when 'r' then :read
                when 'w' then :write
                when '-' then :no_access
                when 'x', 's', 'S', 't', 'T' then :exec
                end
        hash[key] = key.colorize(@colors[color]).freeze
      end
    end

    def init_contents(path)
      info = FileInfo.new(path, link_info = @long)

      if info.directory?
        @contents = Dir.entries(path)

        filter_hidden_contents

        @contents.map! { |e| FileInfo.new(File.join(path, e), link_info = @long) }

        filter_contents if @show
        sort_contents   if @sort
        group_contents  if @group
      else
        @contents = [info]
      end
      @total_content_length = @contents.length

      return @contents unless @long
      init_user_lengths
      init_group_lengths
      @contents
    end

    def filter_hidden_contents
      @contents -= %w[. ..] unless @all
      @contents.keep_if { |x| !x.start_with? '.' } unless @all || @almost_all
    end

    def init_user_lengths
      @userlength = @contents.map do |c|
        c.owner.length
      end.max
    end

    def init_group_lengths
      @grouplength = @contents.map do |c|
        c.group.length
      end.max
    end

    def filter_contents
      @contents.keep_if do |x|
        x.directory? == (@show == :dirs)
      end
    end

    def sort_contents
      case @sort
      when :extension
        @contents.sort_by! do |f|
          name = f.name
          ext = File.extname(name)
          name = name.chomp(ext) unless ext.empty?
          [ext, name].map { |s| CLocale.strxfrm(s) }
        end
      when :time
        @contents.sort_by! { |a| -a.mtime.to_f }
      when :size
        @contents.sort_by! { |a| -a.size }
      else
        @contents.sort_by! { |a| CLocale.strxfrm(a.name) }
      end
      @contents.reverse! if @reverse
    end

    def group_contents
      return unless @group

      dirs, files = @contents.partition(&:directory?)

      @contents = case @group
                  when :dirs then dirs.push(*files)
                  when :files then files.push(*dirs)
                  end
    end

    def init_icons
      @files          = ColorLS::Yaml.new('files.yaml').load
      @file_aliases   = ColorLS::Yaml.new('file_aliases.yaml').load(aliase: true)
      @folders        = ColorLS::Yaml.new('folders.yaml').load
      @folder_aliases = ColorLS::Yaml.new('folder_aliases.yaml').load(aliase: true)

      @file_keys          = @files.keys
      @file_aliase_keys   = @file_aliases.keys
      @folder_keys        = @folders.keys
      @folder_aliase_keys = @folder_aliases.keys

      @all_files   = @file_keys + @file_aliase_keys
      @all_folders = @folder_keys + @folder_aliase_keys
    end

    def display_report
      print "\n   Found #{@total_content_length} contents in directory "
        .colorize(@colors[:report])

      print File.expand_path(@input).to_s.colorize(@colors[:dir])

      puts  "\n\n\tFolders\t\t\t: #{@count[:folders]}"\
        "\n\tRecognized files\t: #{@count[:recognized_files]}"\
        "\n\tUnrecognized files\t: #{@count[:unrecognized_files]}"
        .colorize(@colors[:report])
    end

    def format_mode(rwx, special, char)
      m_r = (rwx & 4).zero? ? '-' : 'r'
      m_w = (rwx & 2).zero? ? '-' : 'w'
      m_x = if special
              (rwx & 1).zero? ? char.upcase : char
            else
              (rwx & 1).zero? ? '-' : 'x'
            end

      @modes[m_r] + @modes[m_w] + @modes[m_x]
    end

    def mode_info(stat)
      m = stat.mode

      format_mode(m >> 6, stat.setuid?, 's') +
        format_mode(m >> 3, stat.setgid?, 's') +
        format_mode(m, stat.sticky?, 't')
    end

    def user_info(content)
      content.owner.ljust(@userlength, ' ').colorize(@colors[:user])
    end

    def group_info(group)
      group.to_s.ljust(@grouplength, ' ').colorize(@colors[:normal])
    end

    def size_info(filesize)
      size = Filesize.from("#{filesize} B").pretty.split(' ')
      size = "#{size[0][0..-4].rjust(4,' ')} #{size[1].ljust(3,' ')}"
      return size.colorize(@colors[:file_large])  if filesize >= 512 * 1024 ** 2
      return size.colorize(@colors[:file_medium]) if filesize >= 128 * 1024 ** 2
      size.colorize(@colors[:file_small])
    end

    def mtime_info(file_mtime)
      mtime = file_mtime.asctime
      now = Time.now
      return mtime.colorize(@colors[:hour_old]) if now - file_mtime < 60 * 60
      return mtime.colorize(@colors[:day_old])  if now - file_mtime < 24 * 60 * 60
      mtime.colorize(@colors[:no_modifier])
    end

    def process_git_status_details(git_status)
      return false unless git_status

      @git_root_path = IO.popen(['git', '-C', @input, 'rev-parse', '--show-toplevel'], err: :close, &:gets)

      return false unless $CHILD_STATUS.success?

      @git_status = Git.status(@git_root_path.chomp!)
    end

    def git_info(path, content)
      return '' unless @git_status

      real_path = File.realdirpath(content.name, path)

      return '    ' unless real_path.start_with? path

      relative_path = real_path.remove(Regexp.new('^' + Regexp.escape(@git_root_path) + '/?'))

      if content.directory?
        git_dir_info(relative_path)
      else
        git_file_info(relative_path)
      end
      # puts "\n\n"
    end

    def git_file_info(path)
      return '  ✓ '.colorize(@colors[:unchanged]) unless @git_status[path]
      Git.colored_status_symbols(@git_status[path].uniq, @colors)
    end

    def git_dir_info(path)
      direct_status = @git_status.fetch("#{path}/", nil)

      return Git.colored_status_symbols(direct_status.uniq, @colors) unless direct_status.nil?

      modes = @git_status.select { |file, mode| file.start_with?(path) && mode != '!!' }

      return '  ✓ '.colorize(@colors[:unchanged]) if modes.empty?

      Git.colored_status_symbols(modes.values.join.uniq, @colors)
    end

    def long_info(content)
      return '' unless @long
      [mode_info(content.stats), user_info(content), group_info(content.group),
       size_info(content.size), mtime_info(content.mtime)].join('  ')
    end

    def symlink_info(content)
      return '' unless @long && content.symlink?
      link_info = " ⇒ #{content.link_target}"
      if content.dead?
        "#{link_info} [Dead link]".colorize(@colors[:dead_link])
      else
        link_info.colorize(@colors[:link])
      end
    end

    def fetch_string(path, content, key, color, increment)
      @count[increment] += 1
      value = increment == :folders ? @folders[key] : @files[key]
      logo  = value.gsub(/\\u[\da-f]{4}/i) { |m| [m[-4..-1].to_i(16)].pack('U') }
      name = content.name
      name = make_link(path, name) if @hyperlink
      name += '/' if content.directory?
      entry = logo + '  ' + name

      "#{long_info(content)} #{git_info(path,content)} #{entry.colorize(color)}#{symlink_info(content)}"
    end

    def ls_line(chunk, widths)
      padding = 0
      line = ''
      chunk.each_with_index do |content, i|
        break if content.nil?

        line += ' ' * padding
        line += "  #{fetch_string(@input, content, *options(content))}"
        padding = widths[i] - content.name.length
      end
      print "#{line}\n"
    end

    def options(content)
      if content.directory?
        key = content.name.to_sym
        color = @colors[:dir]
        return [:folder, color, :folders] unless @all_folders.include?(key)
        key = @folder_aliases[key] unless @folder_keys.include?(key)
        return [key, color, :folders]
      end

      color = @colors[:recognized_file]
      return [content.downcase.to_sym, color, :recognized_files] if @file_keys.include?(key)

      key = content.name.split('.').last.downcase.to_sym
      return [:file, @colors[:unrecognized_file], :unrecognized_files] unless @all_files.include?(key)

      key = @file_aliases[key] unless @file_keys.include?(key)
      [key, color, :recognized_files]
    end

    def tree_traverse(path, prespace, indent)
      contents = init_contents(path)
      contents.each do |content|
        icon = content == contents.last || content.directory? ? ' └──' : ' ├──'
        print tree_branch_preprint(prespace, indent, icon).colorize(@colors[:tree])
        print " #{fetch_string(path, content, *options(content))} \n"
        next unless content.directory?
        tree_traverse("#{path}/#{content}", prespace + indent, indent)
      end
    end

    def tree_branch_preprint(prespace, indent, prespace_icon)
      return prespace_icon if prespace.zero?
      ' │ ' * (prespace/indent) + prespace_icon + '─' * indent
    end

    def make_link(path, name)
      href = "file://#{path}/#{name}"
      "\033]8;;#{href}\007#{name}\033]8;;\007"
    end
  end
end
