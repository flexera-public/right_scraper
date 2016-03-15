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
    subject.finish
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

    let(:cookbook_tar_path) { ::File.join(metadata_scripts_dir, RightScraper::Scanners::CookbookMetadata::TARBALL_ARCHIVE_NAME) }
    let(:untar_cookbook_cmd) { "tar -Pxf #{cookbook_tar_path.inspect}" }
    let(:knife_metadata_cmd) { "export LC_ALL='en_US.UTF-8'; ruby #{knife_metadata_script_path.inspect} #{jailed_cookbook_dir.inspect}" }
    let(:repo_metadata_rb_path) do
      ::File.join(repo_cookbook_dir, described_class::RUBY_METADATA)
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
    let(:freed_metadata_json_path) do
      ::File.join(metadata_scripts_dir, described_class::JSON_METADATA)
    end

    before(:each) do
      ::FileUtils.mkdir_p(repo_dir)
      ::FileUtils.mkdir_p(metadata_scripts_dir)
    end

    context 'when source metadata meets size limit' do

      let(:copy_out) do
        { jailed_metadata_json_path => freed_metadata_json_path }
      end

      let(:generate_metadata_json) do
        ::File.open(freed_metadata_json_path, 'w') do |f|
          f.puts metadata_json
        end
        true
      end

      before(:each) do
        ::FileUtils.mkdir_p(::File.dirname(repo_metadata_rb_path))
        ::File.open(repo_metadata_rb_path, 'w') { |f| f.puts '# some valid metadata' }
        mock_subject = flexmock(subject)
        mock_subject.
          should_receive(:create_tmpdir).
          and_return([metadata_scripts_dir, true])
        mock_subject
      end

      context 'when repo hierarchy is simple' do

        let(:repo_cookbook_dir)   { repo_dir }
        let(:jailed_cookbook_dir) { jailed_repo_dir }

        context 'when generated metadata meets size limit' do
          it 'should generate metadata from source' do
            subject.notice(described_class::RUBY_METADATA) { fail 'unexpected' }
            subject.end(cookbook)
            logged_warnings.should == []
            @parsed_metadata.should == metadata
          end

        end # when generated metadata meets size limit

        context 'when generated metadata exceeds size limit' do
          let(:generate_metadata_json) do
            ::File.open(freed_metadata_json_path, 'w') do |f|
              f.write '{"name":"exceeds generated metadata size limit"'
              key_count = described_class::FREED_FILE_SIZE_CONSTRAINT / 64
              key_count.times { |i| f.write ",\"k#{i}\":#{('v' * 64).inspect}" }
              f.puts '}'
            end
            @generated_file_size = ::File.stat(freed_metadata_json_path).size
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

        before(:each) do
          create_file_layout(repo_dir, repo_hierarchy)
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

      it 'should fail after scrape' do
        subject.notice(described_class::RUBY_METADATA) { fail 'unexpected' }
        message = 'Metadata source file' +
                  " #{described_class::RUBY_METADATA.inspect}" +
                  ' in repository exceeded size constraint of' +
                  " #{described_class::JAILED_FILE_SIZE_CONSTRAINT / 1024} KB"
        expect { subject.end(cookbook) }.
          to raise_error(described_class::MetadataError, message)
      end
    end # when source metadata exceeds size limit

  end # when metadata.json is absent
end # RightScraper::Scanners::CookbookMetadata
