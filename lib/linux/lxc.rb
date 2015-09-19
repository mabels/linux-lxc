require "linux/lxc/version"

module Linux
    class Lxc

      class Line
        attr_reader :lxc, :line, :key
        attr_accessor :value
        def initialize(lxc, key, value)
          @lxc = lxc
          @line = lxc.lines.add(self).length
          @key = key
          @value = value
        end
        def file
          @lxc.file
        end
        def to_s
          if value
            "#{key} = #{value}"
          else
            key
          end
        end
      end

      attr_reader :index, :lines
      attr_accessor :file

      class Lines
        def initialize
          @lines = []
        end
        def add(line)
          @lines << line
          @lines
        end
        def each(&block)
          @lines.each { |line| block.call(line) }
        end
        def values
          @lines.map{|i| i.value}
        end

        def [](idx)
          @lines[idx]
        end

        def length
          @lines.length
        end

        def first
          @lines.first
        end
      end

      def initialize(file, index = {})
        @file = file
        @lines = Lines.new
        @index = index
      end

      def get(key)
        @index[key]
      end

      def add(key, value = nil)
        key = key.strip
        if value and value.instance_of?(String)
          value = value.strip
        end
        line = Line.new(self, key, value)
        path = ""
        dot = ""
        key.split('.').each do |element|
          path += dot + element
          dot = "."
          @index[path] ||= Lines.new
          @index[path].add(line)
        end
      end

      def write
        File.open(file, 'w') do |f|
          @lines.each do |line|
            if line.key == "lxc.include"
              line.value.write
            end
            f.write(line.to_s + "\n")
          end
        end
      end

      def to_s
        @file
      end

      def self.parse(file, index = {})
        lxc = Lxc.new(file, index)
        IO.read(file).lines.each do |line|
          line = line.chop
          if line.match(/^\s*$/) or line.match(/^\s*#.*$/)
              lxc.add(line, nil)
          else
            match = line.match(/^\s*([a-z\.]+)\s*=\s*(.*)\s*$/)
            throw "illegal line in #{@file}:#{@lines.length}" unless match
            if match[1] == 'lxc.include'
              lxc.add(match[1], parse(match[2], index))
            else
              lxc.add(match[1], match[2])
            end
          end
        end
        lxc
      end

    end
end
