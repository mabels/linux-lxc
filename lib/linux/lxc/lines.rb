module Linux
  module Lxc
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
        @lines.map(&:value)
      end

      def remove(line)
        @lines = @lines.select { |i| i != line }
      end

      def [](idx)
        @lines[idx]
      end

      def comment!
        @lines.each(&:comment!)
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
  end
end
