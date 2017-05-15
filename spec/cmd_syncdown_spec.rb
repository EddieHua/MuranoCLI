require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano syncdown', :cmd, :needs_password do
  include_context "CI_CMD"

  before(:example) do
    @project_name = rname('syncdownTest')
    out, err, status = Open3.capture3(capcmd('murano', 'project', 'create', @project_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)
  end
  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @project_name))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  context "without ProjectFile" do
    before(:example) do
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets','files')
      #FileUtils.mkpath('specs')
      #FileUtils.copy(File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'), 'specs/resources.yaml')
    end

    it "syncdown" do
      out, err, status = Open3.capture3(capcmd('murano', 'syncup'))
      expect(out).to eq('')
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)

      FileUtils.rm_r(['files', 'modules', 'routes', 'services'])
      expect(Dir['**/*']).to eq([])

      out, err, status = Open3.capture3(capcmd('murano', 'syncdown'))
      expect(out).to eq('')
      expect(err.lines).to include(
        a_string_ending_with("routes\e[0m\n"),
        a_string_ending_with("files\e[0m\n"),
        a_string_ending_with("modules\e[0m\n"),
        a_string_ending_with("services\e[0m\n"),
      )
      expect(status.exitstatus).to eq(0)

      after = Dir['**/*'].sort
      expect(after).to include("files",
                           "files/icon.png",
                           "files/index.html",
                           "files/js",
                           "files/js/script.js",
                           "modules",
                           "modules/table_util.lua",
                           "routes",
                           "routes/api-fire-{code}.delete.lua",
                           "routes/api-fire-{code}.put.lua",
                           "routes/api-fire.post.lua",
                           "routes/api-onfire.get.lua",
                           "services",
                           "services/device2_event.lua",
                           "services/timer_timer.lua")
    end
  end



  # TODO: With ProjectFile
  # TODO: With Solutionfile 0.2.0
  # TODO: With Solutionfile 0.3.0
end

#  vim: set ai et sw=2 ts=2 :
