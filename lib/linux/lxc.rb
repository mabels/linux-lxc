require_relative 'lxc/version'
require_relative 'lxc/line'
require_relative 'lxc/lines'
require_relative 'lxc/file'
require_relative 'lxc/directory'
require_relative 'lxc/index'

module Linux
  module Lxc
    def self.numeric_prefix_order(data)
      data.sort do |a,b|
        a_m = a.match(/^(\d+)(.*)$/)
        b_m = b.match(/^(\d+)(.*)$/)
        if a_m && b_m
          ret = a_m[1].to_i <=> b_m[1].to_i
          if ret == 0
            ret = a_m[2] <=> b_m[2]
          end
          ret
        else
          a <=> b
        end
      end
    end

    def self.parse(file, index = Index.new)
      if ::File.directory?(file)
        fname = file
        entries = ::Dir.glob(::File.join(file, '*.conf')).select { |f| ::File.file?(f) }
        dir = index.get_directory(fname)
        numeric_prefix_order(entries).each do |entry|
          dir.add_file(entry).parse
        end
        return dir
      end
      return Lxc.file(file, index).parse
    end

    def self.file(fname, index = Index.new)
      dir = index.get_directory(::File.dirname(fname))
      dir.add_file(fname)
    end

    def self.directory(fname, index = Index.new)
      index.get_directory(fname)
    end
  end
end
