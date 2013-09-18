#--
# Copyright: Copyright (c) 2010-2013 RightScale, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# 'Software'), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

# ancestor
require 'right_scraper/loggers'

module RightScraper::Loggers

  # provides a default scraper logger implementation that accumulates errors and
  # warnings but otherwise is a null logger.
  class Default < ::RightScraper::Loggers::Base

    def initialize(*args)
      if args.empty?
        is_windows = !!(RUBY_PLATFORM =~ /mswin|win32|dos|mingw|cygwin/)
        super(is_windows ? 'nul' : '/dev/null')
      else
        super(*args)
      end
      self.level = ::Logger::ERROR
      @recording_messages = true
    end

    # implements Interface#note_error
    def note_error(exception, type, explanation = '')
      without_recording_messages do
        explanation = explanation.to_s.strip
        message = "Saw #{exception ? exception.message : 'error'} during #{type}"
        message += ": #{explanation}" unless explanation.empty?
        error(message)
      end
      @errors << [exception, type, explanation]
    end

    # implements Interface#note_warning
    def note_warning(message)
      without_recording_messages { warn(message) }
      @warnings << message
    end

    # overrides ::Logger#add in order to record errors and warnings logged via
    # the normal logger interface.
    def add(severity, message = nil, progname = nil)
      if severity >= self.level
        # super logger.
        if message.nil?
          if block_given?
            message = yield
          else
            message = progname
            progname = self.progname
          end
        end
        super(severity, message, progname)

        # record errors (with detail) and warnings.
        if @recording_messages
          if severity >= Logger::ERROR
            @errors << [nil, :log, message]
          elsif severity == ::Logger::WARN
            @warnings << message
          end
        end
      end
      true
    end

    protected

    def without_recording_messages
      old_recording_messages = @recording_messages
      @recording_messages = false
      yield
    ensure
      @recording_messages = true
    end
  end
end
