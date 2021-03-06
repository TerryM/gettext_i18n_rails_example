require 'rubygems'
require 'yaml'

current = File.expand_path(File.dirname(File.dirname(__FILE__)))
TEST_RAILS = File.join(current, 'spec', 'rails')

# cleanup old test rails project
`rm -rf #{TEST_RAILS}`

# create a new test rails project that has this plugin installed
`cd #{current}/spec && rails rails`
copy = "#{TEST_RAILS}/vendor/plugins/#{File.basename(current)}"
`ln -s #{current} #{copy}`
`cd #{TEST_RAILS} && ruby -e 'load "#{copy}/install.rb"'` # simulate install hook

GIT_PLUGIN = "git://github.com/grosser/xhr_redirect.git"
OLD_GIT_PLUGIN_COMMITS = ['04f21e015f5419a2383fb430f2428081317ffd95', '1cd9a5bee5cea9b90719ef84dc75616ea2a0ba59']
SVN_PLUGIN = "http://small-plugins.googlecode.com/svn/trunk/will_paginate_acts_as_searchable"

def install_plugin(uri)
  `cd #{TEST_RAILS} && script/plugin install #{uri}`
  name = uri.match(%r{/([^/]+?)(\.git)?$})[1]
  plugin_folder = "#{TEST_RAILS}/vendor/plugins/#{name}"
  [name, plugin_folder]
end

describe 'tracked_plugins' do
  def info_file
    "#{@plugin_folder}/PLUGIN_INFO.yml"
  end

  def plugin_info
    YAML.load(File.read(info_file))
  end

  def change_info(to)
    info = plugin_info
    File.open(info_file,'w'){|f| f.write info.merge(to).to_yaml }
  end

  def script_plugin(cmd, args)
    `cd #{TEST_RAILS} && script/plugin #{cmd} #{args}`
  end

  after :all do
    `rm -rf #{@plugin_folder}` if @plugin_folder
  end

  describe "installing from git" do
    before :all do
      @uri = GIT_PLUGIN
      @name, @plugin_folder = install_plugin(@uri)
    end

    it "checks out the plugin" do
      File.exist?(@plugin_folder).should == true
    end

    it "creates a PLUGIN_INFO.yml" do
      File.exist?("#{@plugin_folder}/PLUGIN_INFO.yml").should == true
    end

    it "writes correct commit" do
      plugin_info[:revision].should =~ /^[\da-f]{40}$/
    end

    it "writes correct installed_at" do
      plugin_info[:installed_at].should be_close(Time.now, 5)
    end

    it "writes correct uri" do
      plugin_info[:uri].should == @uri
    end

    it "writes correct checksum" do
      plugin_info[:checksum].should =~ /^[\da-f]{32}$/
    end
  end

  describe "installing from svn" do
    before :all do
      @uri = SVN_PLUGIN
      @name, @plugin_folder = install_plugin(@uri)
    end

    it "checks out the plugin" do
      File.exist?(@plugin_folder).should == true
    end

    it "creates a PLUGIN_INFO.yml" do
      File.exist?("#{@plugin_folder}/PLUGIN_INFO.yml").should == true
    end

    it "writes correct commit" do
      plugin_info[:revision].should =~ /^\d+$/
    end

    it "writes correct installed_at" do
      plugin_info[:installed_at].should be_close(Time.now, 5)
    end

    it "writes correct uri" do
      plugin_info[:uri].should == @uri
    end
  end

  describe 'list' do
    before :all do
      @uri = GIT_PLUGIN
      @name, @plugin_folder = install_plugin(@uri)
    end

    def list_info
      `cd #{TEST_RAILS} && script/plugin list`.split("\n")[1]
    end

    it "displays meta information" do
      list_info.should =~ %r{^#{@name} #{@uri} [\da-f]+ \d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$}
    end

    it "displays normal information when meta info is missing" do
      `rm #{info_file}`
      list_info.should =~ %r{^#{@name}$}
    end
  end

  describe 'update' do
    before :all do
      @uri = GIT_PLUGIN
      @name, @plugin_folder = install_plugin(@uri)
    end

    it "does not update plugins that do not need update" do
      script_plugin(:update, @name).strip.should == "Plugin is up to date: #{@name} (#{plugin_info[:revision]})"
    end

    it "updates plugins that need update" do
      old_revision = plugin_info[:revision]
      change_info(:revision => 'xxxx')
      script_plugin(:update, @name).strip.should == "Reinstalling plugin: #{@name} (xxxx)"
      plugin_info[:revision].should == old_revision
    end

    it "show 'no meta info' for plugins without info" do
      `rm #{info_file}`
      script_plugin(:update, @name).strip.should == "No meta info found: #{@name}"
    end
  end

  describe 'info' do
    before :all do
      @uri = GIT_PLUGIN
      @name, @plugin_folder = install_plugin(@uri)
    end

    it "shows basic info" do
      script_plugin(:info, @name).strip.should =~ /^checksum: [\da-f]+\ninstalled_at: [^\n]+\nlocally_modified: No\nrevision: [\da-f]+\nupdateable: No\nuri: #{@uri}$/m
    end

    it "does not show modified if it was only touched" do
      `touch #{@plugin_folder}/README.markdown`
      script_plugin(:info, @name).strip.should include('locally_modified: No')
    end

    it "shows modified if it was modified" do
      `echo 111 >> #{@plugin_folder}/README.markdown`
      script_plugin(:info, @name).strip.should include('locally_modified: Yes')
    end

    it "is updateble when current revision is changed" do
      change_info(:revision => 'xxxx')
      script_plugin(:info, @name).should include('updateable: Yes')
    end

    it "is not updateble when current revision is missing" do
      change_info(:revision => '')
      script_plugin(:info, @name).should include('updateable: Unknown')
    end

    describe '--log' do
      before do
        change_info(:revision => OLD_GIT_PLUGIN_COMMITS[0])
      end

      it "does not show log without it" do
        script_plugin(:info, @name).should_not include(OLD_GIT_PLUGIN_COMMITS[1])
      end

      it "shows log" do
        script_plugin(:info, "#{@name} --log").should include(OLD_GIT_PLUGIN_COMMITS[1])
      end

      it "does not show current in log" do
        script_plugin(:info, "#{@name} --log").split(OLD_GIT_PLUGIN_COMMITS[1])[1].should_not include(OLD_GIT_PLUGIN_COMMITS[0])
      end
    end

    it "only shows name when no info is available" do
      `rm #{info_file}`
      script_plugin(:info, @name).strip.should == @name
    end
  end

  describe 'cleanup' do
    it "cleans up" do
      `rm -rf #{TEST_RAILS}`
    end
  end
end