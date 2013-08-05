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
require 'json'

require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'right_scraper', 'scanners', 'cookbook_metadata'))

describe RightScraper::Scanners::CookbookMetadata do

  include RightScraper::SpecHelpers

  let(:base_dir) { ::File.join(::Dir.tmpdir, 'CookbookMetadataSpec_5a436b79') }
  let(:repo_dir) { ::File.join(base_dir, 'repo') }
  let(:cookbook) { flexmock('cookbook') }
  let(:metadata) { {'name' => 'spring_chicken'} }

  let(:metadata_json) { ::JSON.dump(metadata) }

  let(:logged_warnings) { [] }
  let(:logger) do
    mock_logger = flexmock('logger')
    mock_logger.
      should_receive(:operation).
      with(Symbol, Proc).
      and_yield.
      and_return(true)
    warning_buffer = logged_warnings
    mock_logger.
      should_receive(:note_warning).
      with(String).
      and_return { |message| warning_buffer << message; true }
    mock_logger
  end

  subject { described_class.new(:logger => logger) }

  before(:each) do
    ::FileUtils.rm_rf(base_dir) if ::File.directory?(base_dir)
    cookbook.should_receive(:repo_dir).and_return(repo_dir)
    @parsed_metadata = nil
    cookbook.should_receive(:metadata=).with(metadata).and_return { |m| @parsed_metadata = m }
    cookbook.should_receive(:pos).and_return('.').by_default
    subject.begin(cookbook)
  end

  after(:each) do
    ::FileUtils.rm_rf(base_dir) rescue nil if ::File.directory?(base_dir)
  end

  context 'when metadata.json is present' do
    it 'should notice metadata.json file' do
      subject.notice(described_class::JSON_METADATA) { metadata_json }
      subject.end(cookbook)
      @parsed_metadata.should == metadata
    end

    it 'should prefer metadata.json file over metadata.rb' do
      subject.notice(described_class::RUBY_METADATA) { fail 'unexpected' }
      subject.notice(described_class::JSON_METADATA) { metadata_json }
      subject.notice(described_class::RUBY_METADATA) { fail 'unexpected' }
      subject.end(cookbook)
      @parsed_metadata.should == metadata
    end
  end

  context 'when metadata.json is absent' do
    let(:metadata_scripts_dir) { ::File.join(base_dir, 'metadata_scripts') }

    let(:knife_metadata_script_path) do
      ::File.join(
        metadata_scripts_dir,
        ::RightScraper::Scanners::CookbookMetadata::KNIFE_METADATA_SCRIPT_NAME)
    end
    let(:knife_metadata_cmd) { "ruby #{knife_metadata_script_path.inspect}" }
    let(:repo_metadata_rb_path) do
      ::File.join(repo_cookbook_dir, described_class::RUBY_METADATA)
    end
    let(:repo_metadata_json_path) do
      ::File.join(repo_cookbook_dir, described_class::JSON_METADATA)
    end
    let(:jailed_repo_dir) do
      ::File.join(
        metadata_scripts_dir,
        ::RightScraper::Scanners::CookbookMetadata::UNDEFINED_COOKBOOK_NAME)
    end
    let(:jailed_metadata_rb_path) do
      ::File.join(jailed_cookbook_dir, described_class::RUBY_METADATA)
    end
    let(:jailed_metadata_json_path) do
      ::File.join(jailed_cookbook_dir, described_class::JSON_METADATA)
    end

    before(:each) do
      ::FileUtils.mkdir_p(repo_dir)
      ::FileUtils.mkdir_p(metadata_scripts_dir)
    end

    context 'when source metadata meets size limit' do

      let(:copy_out) do
        { jailed_metadata_json_path => repo_metadata_json_path }
      end

      let(:generate_metadata_json) do
        ::File.open(repo_metadata_json_path, 'w') do |f|
          f.puts metadata_json
        end
        true
      end

      let(:warden) do
        mock_warden = flexmock('warden')
        mock_warden.
          should_receive(:run_command_in_jail).
          with(knife_metadata_cmd, copy_in, copy_out).
          once.
          and_return { generate_metadata_json }
        mock_warden.should_receive(:cleanup).and_return(true)
        mock_warden
      end

      before(:each) do
        ::FileUtils.mkdir_p(::File.dirname(repo_metadata_rb_path))
        ::File.open(repo_metadata_rb_path, 'w') { |f| f.puts '# some valid metadata' }
        mock_subject = flexmock(subject)
        mock_subject.should_receive(:create_warden).and_return(warden)
        mock_subject.
          should_receive(:create_tmpdir).
          and_yield(metadata_scripts_dir).
          and_return(nil)
        mock_subject
      end

      context 'when repo hierarchy is simple' do

        let(:repo_cookbook_dir)   { repo_dir }
        let(:jailed_cookbook_dir) { jailed_repo_dir }

        let(:copy_in) do
          {
            knife_metadata_script_path => knife_metadata_script_path,
            repo_metadata_rb_path      => jailed_metadata_rb_path
          }
        end

        context 'when generated metadata meets size limit' do
          it 'should generate metadata from source' do
            subject.notice(described_class::RUBY_METADATA) { fail 'unexpected' }
            subject.end(cookbook)
            logged_warnings.should == []
            @parsed_metadata.should == metadata
          end

          it 'should warn for non-metadata files in repo that exceed size limit' do
            repo_small_file_path = ::File.join(repo_dir, 'small.txt')
            ::File.open(repo_small_file_path, 'w') { |f| f.puts 'small text file' }
            jailed_small_file_path = ::File.join(jailed_repo_dir, 'small.txt')

            repo_big_file_path = ::File.join(repo_dir, 'big.txt')
            ::File.open(repo_big_file_path, 'w') do |f|
              f.puts 'a text file that exceeds size limit'
              line_count = described_class::JAILED_FILE_SIZE_CONSTRAINT / 64
              line_count.times { f.puts 'x' * 64 }
            end

            copy_in.merge!(repo_small_file_path => jailed_small_file_path)
            subject.notice(described_class::RUBY_METADATA) { fail 'unexpected' }
            subject.end(cookbook)
            message =
              "Omitted source file due to size constraint" +
              " #{described_class::JAILED_FILE_SIZE_CONSTRAINT / 1024} KB:" +
              " #{repo_big_file_path.inspect}"
            logged_warnings.should == [message]
            @parsed_metadata.should == metadata
          end
        end # when generated metadata meets size limit

        context 'when generated metadata exceeds size limit' do
          let(:generate_metadata_json) do
            ::File.open(repo_metadata_json_path, 'w') do |f|
              f.write '{"name":"exceeds generated metadata size limit"'
              key_count = described_class::FREED_FILE_SIZE_CONSTRAINT / 64
              key_count.times { |i| f.write ",\"k#{i}\":#{('v' * 64).inspect}" }
              f.puts '}'
            end
            @generated_file_size = ::File.stat(repo_metadata_json_path).size
            true
          end

          it 'should fail on size limit after generating metadata' do
            subject.notice(described_class::RUBY_METADATA) { fail 'unexpected' }
            begin
              subject.end(cookbook)
              fail 'unexpected'
            rescue described_class::MetadataError => e
              message =
                "Generated metadata size of" +
                " #{@generated_file_size / 1024} KB" +
                " exceeded the allowed limit of" +
                " #{described_class::FREED_FILE_SIZE_CONSTRAINT / 1024} KB"
            end
          end
        end # when generated metadata exceeds size limit

        context 'when generated metadata has undefined cookbook name' do
          let(:metadata) { { 'name' => described_class::UNDEFINED_COOKBOOK_NAME } }

          it 'should warn for undefined cookbook name' do
            subject.notice(described_class::RUBY_METADATA) { fail 'unexpected' }
            subject.end(cookbook)
            message =
              'Cookbook name appears to be undefined and has been supplied' +
              ' automatically.'
            logged_warnings.should == [message]
            @parsed_metadata.should == metadata
          end
        end # when generated metadata exceeds size limit
      end # when repo hierarchy is simple

      context 'when repo hierarchy is complex' do

        let(:cookbook_pos) { "cookbooks/#{metadata['name']}" }

        let(:repo_cookbook_dir)   { ::File.join(repo_dir, cookbook_pos) }
        let(:jailed_cookbook_dir) { ::File.join(jailed_repo_dir, cookbook_pos) }

        let(:repo_hierarchy) do
          [
            {
              'cookbooks' => [
                {
                  metadata['name'] => [
                    {
                      'docs'    => ['USAGE.docx'],
                      'recipes' => ['default.rb', 'poached_salmon.rb']
                    },
                    described_class::RUBY_METADATA
                  ],
                  'some_other_cookbook' => [
                    { 'recipes' => ['lepidopterist.rb'] },
                    described_class::RUBY_METADATA
                  ]
                },
                'FAQ.rd'
              ],
              'detritus' => ['something_unrelated']
            },
            'LICENSE',
            'README.md'
          ]
        end

        let(:copy_in) do
          { knife_metadata_script_path => knife_metadata_script_path }
        end

        before(:each) do
          # metadata generator will ignore sibling directories not on direct
          # path from repo_dir to cookbook_dir.
          ignores = [
            ::File.join(repo_dir, 'detritus') + '/',
            ::File.join(repo_dir, 'cookbooks', 'some_other_cookbook') + '/',
          ]
          create_file_layout(repo_dir, repo_hierarchy).reject do |fullpath|
            ignores.any? { |ignore| fullpath.start_with?(ignore) }
          end.each do |fullpath|
            copy_in[fullpath] = jailed_repo_dir + fullpath[repo_dir.length..-1]
          end
          cookbook.should_receive(:pos).and_return(cookbook_pos)
        end

        it 'should generate metadata from source' do
          subject.notice(described_class::RUBY_METADATA) { fail 'unexpected' }
          subject.end(cookbook)
          logged_warnings.should == []
          @parsed_metadata.should == metadata
        end

      end # when repo hierarchy is complex
    end # when source metadata meets size limit

    context 'when source metadata exceeds size limit' do
      let(:repo_cookbook_dir)   { repo_dir }
      let(:jailed_cookbook_dir) { jailed_repo_dir }

      before(:each) do
        ::File.open(repo_metadata_rb_path, 'w') do |f|
          f.puts '# valid metadata that exceeds source size limit'
          line_count = described_class::JAILED_FILE_SIZE_CONSTRAINT / 64
          line_count.times { f.puts "# #{'x' * 64}" }
        end
      end

      it 'should fail before invoking warden' do
        subject.notice(described_class::RUBY_METADATA) { fail 'unexpected' }
        message =
          "Metadata source file exceeded size constraint of" +
          " #{described_class::JAILED_FILE_SIZE_CONSTRAINT / 1024} KB:" +
          " #{repo_metadata_rb_path.inspect}"
        expect { subject.end(cookbook) }.
          to raise_error(described_class::MetadataError, message)
      end
    end # when source metadata exceeds size limit

  end # when metadata.json is absent
end # RightScraper::Scanners::CookbookMetadata
