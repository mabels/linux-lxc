module Linux
  module Lxc
    class Index
      attr_reader :files

      def initialize
        @key_index = {}
        @dirs = {}
        @files = {}
      end

      def add_line(key, line)
        @key_index[key] ||= Lines.new
        @key_index[key].add(line)
      end

      def get_key(key)
        @key_index[key]
      end

      def delete_key(key)
        return if @key_index[key].nil? || !@key_index[key].empty?
        @key_index.delete(key)
      end

      def get_directory(fname)
        @dirs[fname] ||= Directory.new(fname, self)
      end

      def add_file(fname, dir)
        @files[fname] ||= File.new(fname, dir, self)
      end
    end
  end
end
