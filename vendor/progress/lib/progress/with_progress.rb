require 'progress'

class Progress
  class WithProgress
    include Enumerable

    attr_reader :enumerable, :title

    # initialize with object responding to each, title and optional length
    # if block is provided, it is passed to each
    def initialize(enumerable, title, length = nil, &block)
      @enumerable, @title, @length = enumerable, title, length
      each(&block) if block
    end

    # each object with progress
    def each
      enumerable, length = case
      when @length
        [@enumerable, @length]
      when !@enumerable.respond_to?(:length) || @enumerable.is_a?(String) || (defined?(StringIO) && @enumerable.is_a?(StringIO)) || (defined?(TempFile) && @enumerable.is_a?(TempFile))
        elements = @enumerable.each.to_a
        [elements, elements.length]
      else
        [@enumerable, @enumerable.length]
      end

      Progress.start(@title, length) do
        enumerable.each do |object|
          Progress.step do
            yield object
          end
        end
        @enumerable
      end
    end

    # returns self but changes title
    def with_progress(title = nil, length = nil, &block)
      self.class.new(@enumerable, title, length || @length, &block)
    end
  end
end
