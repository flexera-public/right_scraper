#--
# Copyright: Copyright (c) 2013 RightScale, Inc.
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

require 'fileutils'
require 'right_popen'
require 'right_popen/safe_output_buffer'
require 'tmpdir'

module RightScraper
  module Processes
    class Warden

      DEFAULT_RVM_HOME    = '/usr/local/rvm'
      DEFAULT_WARDEN_HOME = '/opt/warden'

      RELATIVE_SCRIPTS_RVM_PATH = 'scripts/rvm'

      # TEAL FIX: dynamically discover highest rvm-installed ruby 1.9 build?
      DEFAULT_RVM_RUBY_VERSION = 'ruby-1.9.3-p448'

      WARDEN_SERVICE_SUBDIR_NAME  = 'warden'
      RELATIVE_WARDEN_SCRIPT_PATH = 'bin/warden'

      WARDEN_COMMAND_TIMEOUT = 60 # max seconds to spawn, link, etc.

      DEFAULT_OPTIONS = {
        :warden_home      => DEFAULT_WARDEN_HOME,
        :rvm_home         => DEFAULT_RVM_HOME,
        :rvm_ruby_version => DEFAULT_RVM_RUBY_VERSION
      }

      # marshalling
      class LinkResult
        attr_reader :exit_status, :stdout, :stderr

        def initialize(link_result)
          @exit_status = link_result['exit_status'].to_i rescue 1
          @stdout = link_result['stdout'].to_s
          @stderr = link_result['stderr'].to_s
        end

        def succeeded?
          0 == exit_status
        end
      end

      # exceptions
      class StateError < Exception; end
      class WardenError < Exception; end

      class LinkError < Exception
        attr_reader :link_result

        def initialize(message, link_result)
          super(message)
          @link_result = link_result
        end
      end

      def initialize(options = {})
        options = DEFAULT_OPTIONS.merge(options)
        @warden_home = options[:warden_home]
        @rvm_home = options[:rvm_home]
        unless @rvm_ruby_version = options[:rvm_ruby_version]
          raise ArgumentError.new('options[:rvm_ruby_version] is required')
        end

        # warden paths
        unless @warden_home && ::File.directory?(@warden_home)
          raise ArgumentError.new('options[:warden_home] is required')
        end
        unless @rvm_home && ::File.directory?(@rvm_home)
          raise ArgumentError.new('options[:rvm_home] is required')
        end
        @warden_server_dir = ::File.join(@warden_home, WARDEN_SERVICE_SUBDIR_NAME)
        @bin_warden_path = ::File.join(@warden_server_dir, RELATIVE_WARDEN_SCRIPT_PATH)
        unless File.file?(@bin_warden_path)
          raise StateError, "Warden CLI script cannot be found at #{@bin_warden_path.inspect}"
        end

        # rvm paths
        @scripts_rvm_path = ::File.join(@rvm_home, RELATIVE_SCRIPTS_RVM_PATH)
        unless File.file?(@scripts_rvm_path)
          raise StateError, "RVM setup script cannot be found at #{@scripts_rvm_path.inspect}"
        end

        # build the jail.
        @handle = send('create')['handle']
        raise StateError, 'handle is invalid' unless @handle
      end

      # Runs the script given by container-relative path. Optionally copies
      # files in/out before/after script execution.
      #
      # === Parameters
      # @param [String|Array] cmds to execute
      # @param [Hash] copy_in files as map of host source path to jail destination path or empty or nil
      # @param [Hash] copy_out files as map of jail source path to host destination path or empty or nil
      #
      # === Return
      # @return [String] stdout text
      #
      # === Raise
      # @raise [StateError] for invalid state
      # @raise [LinkError] for link (to script output) failure
      # @raise [WardenError] for warden failure
      def run_command_in_jail(cmds, copy_in = nil, copy_out = nil)
        cmds = Array(cmds)
        raise ArgumentError, 'cmds is required' if cmds.empty?
        raise StateError, 'handle is invalid' unless @handle

        # copy any files in before running commands.
        if copy_in && !copy_in.empty?
          send_copy_in_cmds(copy_in)
        end

        # note that appending --privileged will run script as root, but we have
        # no use case for running scripts as root at this time.
        output = []
        cmds.each do |cmd|
          job_id = send("spawn --handle #{@handle} --script #{cmd.inspect}")['job_id']
          link_result = LinkResult.new(send("link --handle #{@handle} --job_id #{job_id}"))
          if link_result.succeeded?
            output << link_result.stdout
          else
            raise LinkError.new('Script failed running in isolation.', link_result)
          end
        end

        # copy any files out after command(s) succeeded.
        if copy_out && !copy_out.empty?
          copy_out_cmds = copy_out.inject([]) do |result, (src_path, dst_path)|
            # create output directories because warden will only copy files.
            parent_dir = ::File.dirname(dst_path)
            ::FileUtils.mkdir_p(parent_dir)
            result << "copy_out --handle #{@handle} --src_path #{src_path.inspect} --dst_path #{dst_path.inspect}"
            result
          end
          send(copy_out_cmds)
        end

        return output.join("\n")
      end

      def cleanup
        raise StateError, 'handle is invalid' unless @handle
        lay_to_rest
        send("destroy --handle #{@handle}")
      ensure
        @handle = nil
      end

      private

      def create_uuid
        (0..15).to_a.map{|a| rand(16).to_s(16)}.join
      end

      # warden doesn't create directories on copy_in (or _out) so we need to
      # generate a script and execute it before invoking copy_in.
      def send_copy_in_cmds(copy_in)
        mkdir_cmds = copy_in.values.
          map { |dst_path| ::File.dirname(dst_path) }.uniq.sort.
          map { |parent_dir| "mkdir -p #{parent_dir}" }
        shell_script = <<EOS
#!/bin/bash
rm $0  # this script will self-destruct
#{mkdir_cmds.join(" &&\n")}
EOS

        mkdir_script_name = "mkdir_script_#{create_uuid}.sh"
        mkdir_script_path = ::File.join(::Dir.tmpdir, mkdir_script_name)
        ::File.open(mkdir_script_path, 'w') { |f| f.puts shell_script }
        create_parent_dir_cmds = [
          "copy_in --handle #{@handle} --src_path #{mkdir_script_path} --dst_path #{mkdir_script_path}",
          "spawn --handle #{@handle} --script '/bin/bash #{mkdir_script_path}'"
        ]
        job_id = send(create_parent_dir_cmds)['job_id']
        link_result = LinkResult.new(send("link --handle #{@handle} --job_id #{job_id}"))
        if link_result.succeeded?
          copy_in_cmds = copy_in.inject([]) do |result, (src_path, dst_path)|
            result << "copy_in --handle #{@handle} --src_path #{src_path.inspect} --dst_path #{dst_path.inspect}"
            result
          end
          send(copy_in_cmds)
        else
          raise LinkError.new('Failed to create parent directories for files to be copied.', link_result)
        end
        true
      end

      # Sends one or more commands to warden and accumulates the stdout and
      # stderr from those commands.
      def send(warden_cmd)
        # warden runs in a ruby 1.9.3 environment, for which we need rvm and a
        # slew of fancy setup on the assumption that the current environemnt is
        # not that. ideally this code would run in a standalone service where
        # the warden-client gem could be used to simplify some of this.
        warden_cmds = Array(warden_cmd).map do |line|
          # execute bin/warden (Geronimo)
          "bundle exec #{RELATIVE_WARDEN_SCRIPT_PATH} -- #{line}"
        end

        shell_script = <<EOS
#!/bin/bash
source #{@scripts_rvm_path} 1>/dev/null &&
rvm use #{@rvm_ruby_version} 1>/dev/null &&
cd #{@warden_server_dir} 1>/dev/null &&
#{warden_cmds.join(" &&\n")}
EOS

        # ensure bundler env vars for current process don't interfere.
        ::Bundler.with_clean_env do
          ::Dir.mktmpdir do |tmpdir|
            @process = nil
            @interupted_to_close = false
            @stdout_buffer = []
            @stderr_buffer = ::RightScale::RightPopen::SafeOutputBuffer.new
            warden_script_path = ::File.join(tmpdir, "run_warden_#{create_uuid}.sh")
            ::File.open(warden_script_path, 'w') { |f| f.puts shell_script }
            cmd = "/bin/bash #{warden_script_path}"
            ::RightScale::RightPopen.popen3_sync(
              cmd,
              :target          => self,
              :inherit_io      => true,  # avoid killing any rails connection
              :watch_handler   => :watch_warden,
              :stderr_handler  => :stderr_warden,
              :stdout_handler  => :stdout_warden,
              :timeout_handler => :timeout_warden,
              :exit_handler    => :exit_warden,
              :timeout_seconds => WARDEN_COMMAND_TIMEOUT)
            if @process
              @process = nil
              warden_output = @stdout_buffer.join
              if warden_output.empty?
                result = {}
              else
                result = parse_warden_output(warden_output)
              end
              return result
            else
              raise WardenError, 'Unable to execute warden.'
            end
          end
        end
      end

      # Warden outputs something that looks like YAML but also somewhat like a
      # Java configuration file. in any case, the output is ambiguous because it
      # does not escape characters and it is possible to spawn a process that
      # prints output text that appears to be the start of a new key. *sigh*
      #
      # all we can do here is attempt to parse the output by some simple rules
      # and hope for the best.
      #
      # example:
      #   exit_status : 0
      #   stdout : a
      #   b
      #   c
      #
      #   stderr :
      #   info.state : active
      #   ...
      def parse_warden_output(warden_output)
        parsed_lines = {}
        current_key = nil
        regex = /^([a-z._]+) \: (.*)$/
        warden_output.lines.each do |line|
          if parts = regex.match(line)
            current_key = parts[1]
            parsed_lines[current_key] = [parts[2]]
          elsif current_key
            parsed_lines[current_key] << line.chomp
          else
            raise WardenError, "Unable to parse warden output:\n#{warden_output.inspect}"
          end
        end
        parsed_lines.inject({}) do |result, (key, value)|
          result[key] = value.join("\n")
          result
        end
      end

      def lay_to_rest
        if @process
          if @process.interrupt
            @interupted_to_close = true
            @process.sync_exit_with_target
          else
            @process.safe_close_io
          end
        end
      end

      def stdout_warden(data)
        @stdout_buffer << data
      end

      def stderr_warden(data)
        @stderr_buffer.safe_buffer_data(data)
      end

      def watch_warden(process)
        if @interupted_to_close
          true
        else
          @process = process
        end
      end

      def timeout_warden
        unless @interupted_to_close
          raise WardenError, 'Timed out waiting for warden to respond'
        end
      end

      def exit_warden(status)
        unless @interupted_to_close || status.success?
          raise WardenError,
                "Warden failed exit_status = #{status.exitstatus}:\n" +
                "stdout = #{@stdout_buffer.join}\n" +
                "stderr = #{@stderr_buffer.display_text}"
        end
        true
      end

    end # Warden
  end # Processes
end # RightScraper
