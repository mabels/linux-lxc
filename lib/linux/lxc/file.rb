require 'fileutils'

module Linux
  module Lxc
    class File
      attr_reader :index, :lines, :file, :dir
      attr_accessor :real_fname

      def initialize(file, dir, index)
        self.file = file
        @dir = dir
        @lines = Lines.new
        @index = index
      end

      # file is more important than real_fname
      def file=(a)
        @file = a
        @real_fname = a
      end

      def get(key)
        @index.get_key(key)
      end

      def key_to_path(key, &block)
        path = ''
        dot = ''
        key.split('.').each do |element|
          path += dot + element
          dot = '.'
          # puts ">>>>#{path}"
          block.call(path)
        end
      end

      def remove_from_index(line)
        key_to_path(line.key) do |path|
          lines = @index.get_key(path)
          lines.remove(line)
          @index.delete_key(path)
        end
      end

      def add(key, value = nil)
        key = key.strip
        value = value.strip if value && value.instance_of?(String)
        line = Line.new(self, key, value)
        add_to_index(line)
      end

      def add_to_index(line)
        key_to_path(line.key) do |path|
          @index.add_line(path, line)
        end
      end

      def all_lines(&block)
        @lines.each do |line|
          block.call(line)
          line.value.all_lines(&block) if line.value.respond_to?(:all_lines)
        end
      end

      # def files
      #   ret = [Line.new(nil, 'lxc.include', self)]
      #   all_lines do |line|
      #     line.value.instance_of?(File) && (ret << line)
      #   end
      #   ret
      # end

      def entries
        {file => self}
      end

      def write
        FileUtils.mkdir_p ::File.dirname(real_fname)
        ::File.open(real_fname, 'w') do |f|
          @lines.each do |line|
            if line.key == 'lxc.include'
              line.value.write
              f.write(line.to_s + "\n")
            else
              f.write(line.to_s + "\n")
            end
          end
        end
      end

      def to_s
        @file
      end

      def parse
        IO.read(file).lines.each do |line|
          line = line.chop
          if line.match(/^\s*$/)
            self.add(line, nil)
          elsif line.match(/^\s*#.*$/)
            self.add('#', line)
          else
            match = line.match(/^\s*([a-z0-9\-_\.]+)\s*=\s*(.*)\s*$/)
            throw "illegal line in #{@file}:#{@lines.length}" unless match
            if match[1] == 'lxc.include'
              self.add(match[1], Lxc.parse(match[2], index))
            else
              self.add(match[1], match[2])
            end
          end
        end

        self
      end
    end
  end
end
