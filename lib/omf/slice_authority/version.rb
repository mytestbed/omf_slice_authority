
module OMF
  module SliceAuthority
    VERSION = [0, 5, 'pre']
    @@version = nil

    def self.version
      return @@version if @@version
      version = VERSION.join('.')
      @@version = version_append_git_commit(version, File.join(File.dirname(__FILE__), '/../../../.git'))
    end

    def self.version_append_git_commit(version, git_dir)
      git_dir = File.absolute_path(git_dir)
      if File.exist? git_dir
        cs = `git --git-dir #{git_dir} log -n 1 2> /dev/null`
        unless cs.empty?
          version += '-' + cs[7, 8]
        end
      end
      version
    end

  end
end
