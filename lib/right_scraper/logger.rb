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

require 'logger'

module RightScraper
  # Very simplistic logger for scraper operations.
  class Logger < ::Logger
    # If no arguments, create a Logger that logs to nothing.
    # Otherwise pass the arguments on to ::Logger.
    def initialize(*args)
      if args.empty?
        super('/dev/null')
        self.level = ::Logger::ERROR
      else
        super
      end
      @exceptional = false
    end

    # (RightScraper::Repositories::Base) Repository currently being examined.
    attr_writer :repository

    # Begin an operation that merits logging.  Will call #note_error
    # if an exception is raised during the operation.
    #
    # === Parameters
    # type(Symbol):: operation type identifier
    # explanation(String):: optional explanation
    def operation(type, explanation="")
      begin
        note_phase(:begin, type, explanation)
        result = yield
        note_phase(:commit, type, explanation)
        result
      rescue Exception => e
        note_phase(:abort, type, explanation, e)
        raise
      end
    end

    # Note an event to the log.  In this base class this calls
    # note_error when an error occurs, but subclasses will presumably
    # want to override it.
    #
    # === Parameters
    # phase(Symbol):: phase of operation; one of :begin, :commit, :abort
    # type(Symbol):: operation type identifier
    # explanation(String):: explanation of operation
    # exception(Exception):: optional exception (only if +phase+ is :abort)
    def note_phase(phase, type, explanation, exception=nil)
      case phase
      when :begin then @exceptional = false
      when :abort then
        unless @exceptional
          note_error(exception, type, explanation)
          @exceptional = true
        end
      end
    end

    # Log an error, with the given exception and explanation of what
    # was going on.
    #
    # === Parameters
    # exception(Exception):: exception raised
    # type(Symbol):: operation type identifier
    # explanation(String):: optional explanation
    def note_error(exception, type, explanation="")
      error("Saw #{exception} during #{type}#{maybe_explain(explanation)}")
    end

    def note_warning(message)
      warn(message)
    end

    protected
    def maybe_explain(explanation)
      if explanation.nil? || explanation.empty?
        ""
      else
        ": #{explanation}"
      end
    end
  end
end
