require File.dirname(__FILE__) + '/spec_helper.rb'

describe Progress do
  let(:count){ 165 }

  before :each do
    @io = StringIO.new
    Progress.instance_variable_set(:@io, @io)
    def Progress.time_to_print?; true; end
  end

  def io_pop
    @io.seek(0)
    s = @io.read
    @io.truncate(0)
    @io.seek(0)
    s
  end

  def io_pop_no_eta
    io_pop.sub(/ \(ETA: \d+.\)$/, '')
  end

  def verify_output_before_step(i, count)
    io_pop.should =~ /#{Regexp.quote(i == 0 ? '......' : '%5.1f' % (i / count.to_f * 100.0))}/
  end
  def verify_output_after_stop
    io_pop.should =~ /100\.0.*\n$/
  end

  describe 'direct usage' do
    describe 'procedural' do
      it "should show valid output when called as Progress.start" do
        Progress.start('Test', count)
        count.times do |i|
          verify_output_before_step(i, count)
          Progress.step
        end
        Progress.stop
        verify_output_after_stop
      end

      it "should show valid output when called as Progress" do
        Progress('Test', count)
        count.times do |i|
          verify_output_before_step(i, count)
          Progress.step
        end
        Progress.stop
        verify_output_after_stop
      end

      it "should show valid output when called without title" do
        Progress(count)
        count.times do |i|
          verify_output_before_step(i, count)
          Progress.step
        end
        Progress.stop
        verify_output_after_stop
      end
    end

    describe 'block' do
      it "should show valid output when called as Progress.start" do
        Progress.start('Test', count) do
          count.times do |i|
            verify_output_before_step(i, count)
            Progress.step
          end
        end
        verify_output_after_stop
      end

      it "should show valid output when called as Progress" do
        Progress('Test', count) do
          count.times do |i|
            verify_output_before_step(i, count)
            Progress.step
          end
        end
        verify_output_after_stop
      end

      it "should show valid output when called without title" do
        Progress(count) do
          count.times do |i|
            verify_output_before_step(i, count)
            Progress.step
          end
        end
        verify_output_after_stop
      end
    end
  end

  describe 'integrity' do
    it "should not raise errors on extra Progress.stop" do
      proc{
        10.times_with_progress('10') do
          Progress.start 'simple' do
            Progress.start 'procedural'
            Progress.stop
            Progress.stop
          end
          Progress.stop
        end
        Progress.stop
      }.should_not raise_error
    end

    it "should return result from block" do
      Progress.start('Test') do
        'qwerty'
      end.should == 'qwerty'
    end

    it "should return result from step" do
      Progress.start do
        Progress.step{ 'qwerty' }.should == 'qwerty'
      end
    end

    it "should return result from set" do
      Progress.start do
        Progress.set(1){ 'qwerty' }.should == 'qwerty'
      end
    end

    it "should return result from nested block" do
      [1, 2, 3].with_progress('a').map do |a|
        [1, 2, 3].with_progress('b').map do |b|
          a * b
        end
      end.should == [[1, 2, 3], [2, 4, 6], [3, 6, 9]]
    end

    it "should kill progress on cycle break" do
      2.times do
        catch(:lalala) do
          2.times_with_progress('A') do |a|
            io_pop.should == "A: ......\n"
            2.times_with_progress('B') do |b|
              io_pop.should == "A: ...... > B: ......\n"
              throw(:lalala)
            end
          end
        end
        io_pop.should == "A: ......\n\n"
      end
    end

    [[2, 200], [20, 20], [200, 2]].each do |_a, _b|
      it "should allow enclosed progress [#{_a}, #{_b}]" do
        _a.times_with_progress('A') do |a|
          io_pop_no_eta.should == "A: #{a == 0 ? '......' : '%5.1f%%'}\n" % [a / _a.to_f * 100.0]
          _b.times_with_progress('B') do |b|
            io_pop_no_eta.should == "A: #{a == 0 && b == 0 ? '......' : '%5.1f%%'} > B: #{b == 0 ? '......' : '%5.1f%%'}\n" % [(a + b / _b.to_f) / _a.to_f * 100.0, b / _b.to_f * 100.0]
          end
          io_pop_no_eta.should == "A: %5.1f%% > B: 100.0%%\n" % [(a + 1) / _a.to_f * 100.0]
        end
        io_pop.should == "A: 100.0%\nA: 100.0%\n\n"
      end

      it "should not overlap outer progress if inner exceeds [#{_a}, #{_b}]" do
        _a.times_with_progress('A') do |a|
          io_pop_no_eta.should == "A: #{a == 0 ? '......' : '%5.1f%%'}\n" % [a / _a.to_f * 100.0]
          Progress.start('B', _b) do
            (_b * 2).times do |b|
              io_pop_no_eta.should == "A: #{a == 0 && b == 0 ? '......' : '%5.1f%%'} > B: #{b == 0 ? '......' : '%5.1f%%'}\n" % [(a + [b / _b.to_f, 1].min) / _a.to_f * 100.0, b / _b.to_f * 100.0]
              Progress.step
            end
          end
          io_pop_no_eta.should == "A: %5.1f%% > B: 200.0%%\n" % [(a + 1) / _a.to_f * 100.0]
        end
        io_pop.should == "A: 100.0%\nA: 100.0%\n\n"
      end

      it "should allow step with block to validly count custom progresses [#{_a}, #{_b}]" do
        a_step = 99
        Progress.start('A', _a * 100) do
          io_pop_no_eta.should == "A: ......\n"
          _a.times do |a|
            Progress.step(a_step) do
              _b.times_with_progress('B') do |b|
                io_pop_no_eta.should == "A: #{a == 0 && b == 0 ? '......' : '%5.1f%%'} > B: #{b == 0 ? '......' : '%5.1f%%'}\n" % [(a * a_step + b / _b.to_f * a_step) / (_a * 100).to_f * 100.0, b / _b.to_f * 100.0]
              end
              io_pop_no_eta.should == "A: %5.1f%% > B: 100.0%\n" % [(a + 1) * a_step.to_f / (100.0 * _a.to_f) * 100.0]
            end
            io_pop_no_eta.should == "A: %5.1f%%\n" % [(a + 1) * a_step.to_f / (100.0 * _a.to_f) * 100.0]
          end
          Progress.step _a
        end
        io_pop.should == "A: 100.0%\nA: 100.0%\n\n"
      end
    end
  end

  describe Enumerable do
    before :each do
      @a = 0...1000
    end

    describe 'with_progress' do
      it "should not break each" do
        with, without = [], []
        @a.with_progress.each{ |n| with << n }
        @a.each{ |n| without << n }
        with.should == without
      end

      it "should not break find" do
        @a.with_progress('Hello').find{ |n| n == 100 }.should == @a.find{ |n| n == 100 }
        @a.with_progress('Hello').find{ |n| n == 10000 }.should == @a.find{ |n| n == 10000 }
        default = proc{ 'default' }
        @a.with_progress('Hello').find(default){ |n| n == 10000 }.should == @a.find(default){ |n| n == 10000 }
      end

      it "should not break map" do
        @a.with_progress('Hello').map{ |n| n * n }.should == @a.map{ |n| n * n }
      end

      it "should not break grep" do
        @a.with_progress('Hello').grep(100).should == @a.grep(100)
      end

      it "should not break each_cons" do
        without_progress = []
        @a.each_cons(3){ |values| without_progress << values }
        with_progress = []
        @a.with_progress('Hello').each_cons(3){ |values| with_progress << values }
        without_progress.should == with_progress
      end

      describe "with_progress.with_progress" do
        it "should not change existing instance" do
          wp = @a.with_progress('hello')
          proc{ wp.with_progress('world') }.should_not change(wp, :title)
        end

        it "should create new instance with different title when called on WithProgress" do
          wp = @a.with_progress('hello')
          wp_wp = wp.with_progress('world')
          wp.title.should == 'hello'
          wp_wp.title.should == 'world'
          wp_wp.should_not == wp
          wp_wp.enumerable.should == wp.enumerable
        end
      end

      describe "calls to each" do
        class CallsToEach
          include Enumerable

          COUNT = 100
        end

        def init_calls_to_each
          @enum = CallsToEach.new
          @objects = 10.times.to_a
          @enum.should_receive(:each).once{ |&block|
            @objects.each(&block)
          }
        end

        it "should call each only one time for object with length" do
          init_calls_to_each
          @enum.should_receive(:length).and_return(10)
          got = []
          @enum.with_progress.each{ |o| got << o }.should == @enum
          got.should == @objects
        end

        it "should call each only one time for object without length" do
          init_calls_to_each
          got = []
          @enum.with_progress.each{ |o| got << o }.should == @enum
          got.should == @objects
        end

        it "should call each only one time for String" do
          @objects = ('a'..'z').map{ |c| "#{c}\n" }
          str = @objects.join('')
          str.should_not_receive(:length)
          str.should_receive(:each).once{ |&block|
            @objects.each(&block)
          }
          got = []
          str.with_progress.each{ |o| got << o }.should == str
          got.should == @objects
        end
      end
    end
  end

  describe Integer do
    describe 'with times_with_progress' do
      it "should not break times" do
        ii = 0
        count.times_with_progress('Test') do |i|
          i.should == ii
          ii += 1
        end
      end

      it "should show valid output for each_with_progress" do
        count.times_with_progress('Test') do |i|
          verify_output_before_step(i, count)
        end
        verify_output_after_stop
      end

      it "should show valid output for each_with_progress without title" do
        count.times_with_progress do |i|
          verify_output_before_step(i, count)
        end
        verify_output_after_stop
      end
    end
  end
end
