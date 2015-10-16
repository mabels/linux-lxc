#      def glob?
#        @used_glob
#      end

#      def get_entries
#        entries = []
#        if ::File.directory?(file)
#          @used_glob = true
#          entries += ::Dir.glob(::File.join(file, "*")).select{|f| ::File.file?(f) }
#        elsif ::File.file?(file)
#          entries += [file]
#        end
#        entries
#      end


module Linux
  module Lxc
    class Directory
      attr_reader :entries, :index, :file
      def initialize(fname, index)
        @file = fname
        @index = index
        @entries = {}
      end

      def all_lines(&block)
        @entries.values.each do |entry|
          entry.all_lines(&block)
        end
      end

      def to_s
        @file
      end

      def get(key)
        @index.get_key(key)
      end

      def add_file(fname)
        @entries[fname] ||= @index.add_file(fname, self)
      end

      def write
        FileUtils.mkdir_p file
        @entries.values.each do |entry|
          entry.write
        end
      end
    end
  end
end
