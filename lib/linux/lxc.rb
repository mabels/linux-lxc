require "linux/lxc/version"

module Linux
    class Lxc

      class Line
        attr_reader :lxc, :line, :key
        attr_accessor :value
        def initialize(lxc, key, value)
          @lxc = lxc
          @line = lxc && lxc.lines.add(self).length
          @key = key
          @value = value
        end
        def file
          @lxc.file
        end
        def comment!
          return if @key == '#'
          # remove from index
          lxc.remove_from_index(self)
          @key = '#'
          @value = '# ' + self.to_s
          lxc.add_to_index(self)
        end
        def to_s
          if value
            "#{key} = #{value}"
          else
            key
          end
        end
      end


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

        def remove(line)
          @lines = @lines.select{|i| i != line }
        end

        def [](idx)
          @lines[idx]
        end

        def comment!
          @lines.each{|i| i.comment! }
        end

        def length
          @lines.length
        end

        def empty?
          @lines.empty?
        end

        def first
          @lines.first
        end
      end

      attr_reader :index, :lines
      attr_accessor :file

      def initialize(file, index = {})
        @file = file
        @lines = Lines.new
        @index = index
      end

      def get(key)
        @index[key]
      end

      def key_to_path(key, &block)
        path = ""
        dot = ""
        key.split('.').each do |element|
          path += dot + element
          dot = "."
          #puts ">>>>#{path}"
          block.call(path)
        end
      end

      def remove_from_index(line)
        key_to_path(line.key) do |path|
          get(path).remove(line)
          get(path).empty? && @index.delete(path)
        end
      end

      def add(key, value = nil)
        key = key.strip
        if value and value.instance_of?(String)
          value = value.strip
        end
        line = Line.new(self, key, value)
        add_to_index(line)
      end

      def add_to_index(line)
        key_to_path(line.key) do |path|
          @index[path] ||= Lines.new
          @index[path].add(line)
        end
      end

      def all_lines(&block)
        @lines.each do |line|
          block.call(line)
          if line.value.instance_of?(Lxc)
            line.value.all_lines(&block)
          end
        end
      end

      def files
        ret = [Line.new(nil, "lxc.include", self)]
        all_lines {|line| line.value.instance_of?(Lxc) && (ret << line) }
        ret
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
          if line.match(/^\s*$/)
              lxc.add(line, nil)
          elsif line.match(/^\s*#.*$/)
              lxc.add('#', line)
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
