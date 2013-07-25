#--
# Copyright: Copyright (c) 2010-2011 RightScale, Inc.
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

module RightScraper

  class ScraperLogger < Logger
    attr_accessor :callback, :errors, :warnings

    def add(severity, message=nil, progname=nil)
      if severity >= (self.level || Logger::WARN)
        if message.nil?
          if block_given?
            message = yield
          else
            message = progname
            progname = self.progname
          end
        end
        @errors << [nil, :log,
          {:severity => severity,
            :message => message,
            :progname => progname}]
      end
    end

    def initialize
      @errors = []
      @warnings = []
    end

    def note_phase(phase, type, explanation, exception=nil)
      @callback.call(phase, type, explanation, exception) unless @callback.nil?
      super
    end

    def note_error(exception, type, explanation="")
      @errors << [exception, type, explanation]
    end

    def note_warning(message)
      @warnings << message
    end

  end

end
