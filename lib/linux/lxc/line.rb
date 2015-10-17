module Linux
  module Lxc
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
        uncomment = to_s
        @key = '#'
        @value = '# ' + uncomment
        lxc.add_to_index(self)
      end

      def to_s
        if value
          if key == '#'
            value
          else
            "#{key} = #{value}"
          end
        else
          key
        end
      end
    end
  end
end
