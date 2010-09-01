#--
# Copyright: Copyright (c) 2010 RightScale, Inc.
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

module RightScale
  module FullScraperHelpers
    shared_examples_for "Normal repository contents" do
      it 'should scrape' do
        @scraper.scrape(@repo)
        @scraper.succeeded?.should be_true
        @scraper.cookbooks.should_not == []
        @scraper.cookbooks.size.should == 1
        @scraper.cookbooks[0].data.should_not have_key(:archive)
        @scraper.cookbooks[0].manifest.should == {
                "folder1/file3"=>"1eb2267bae4e47cab81f8866bbc7e06764ea9be0",
                "file1"=>"38be7d1b981f2fb6a4a0a052453f887373dc1fe8",
                "folder2/folder3/file4"=>"a441d6d72884e442ef02692864eee99b4ad933f5",
                "metadata.json"=>"c2901d21c81ba5a152a37a5cfae35a8e092f7b39",
                "folder1/file2"=>"639daad06642a8eb86821ff7649e86f5f59c6139"}
        @scraper.cookbooks[0].metadata.should == [{"folder1"=>["file2", "file3"]},
                                                  {"folder2"=>[{"folder3"=>["file4"]}]},
                                                  "file1"]
      end
    end
  end
end
