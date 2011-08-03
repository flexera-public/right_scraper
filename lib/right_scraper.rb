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

# Explicitly list required files to make IDEs happy
require 'fileutils'
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'builders', 'base'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'builders', 'filesystem'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'builders', 'union'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'logger'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'processes', 'ssh'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'repositories', 'base'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'repositories', 'download'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'repositories', 'git'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'repositories', 'svn'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'resources', 'base'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'resources', 'cookbook'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'resources', 'workflow'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'retrievers', 'base'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'retrievers', 'checkout'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'retrievers', 'download'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'retrievers', 'git'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'retrievers', 'svn'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'scanners', 'base'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'scanners', 'cookbook_manifest'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'scanners', 'cookbook_metadata'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'scanners', 'cookbook_s3_upload'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'scanners', 'union'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'scanners', 'workflow_manifest'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'scanners', 'workflow_metadata'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'scraper'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'scraper_logger'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'scrapers', 'base'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'scrapers', 'cookbook'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'scrapers', 'workflow'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'svn_client'))
require File.expand_path(File.join(File.dirname(__FILE__), 'right_scraper', 'version'))
