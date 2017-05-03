require 'MrMurano/version'
require 'MrMurano/Config'
require 'MrMurano/Product-Resources'
require '_workspace'

RSpec.describe MrMurano::OnePlatform::Resources do
  include_context "WORKSPACE"
  before(:example) do
    MrMurano::SyncRoot.reset
    $cfg = MrMurano::Config.new
    $cfg.load
    $project = MrMurano::ProjectFile.new
    $project.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['product.id'] = 'XYZ'
    $cfg['product.spec'] = 'XYZ.yaml'

    @prd = MrMurano::OnePlatform::Resources.new
    allow(@prd).to receive(:token).and_return("TTTTTTTTTT")
    allow(@prd).to receive(:model_rid).and_return("LLLLLLLLLL")
  end

  it "initializes" do
    uri = @prd.endPoint('')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process")
  end

  context "queries" do
    it "gets info" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"info",
                              :arguments=>["LLLLLLLLLL", {}]} ]}).
        to_return(body: [{:id=>1, :status=>"ok", :result=>{:comments=>[]}}])

      ret = @prd.info
      expect(ret).to eq({:comments=>[]})
    end

    it "gets listing" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"info",
                              :arguments=>["LLLLLLLLLL", {}]} ]}).
        to_return(body: [{:id=>1, :status=>"ok", :result=>{:aliases=>{:abcdefg=>["bob"]}}}])

      ret = @prd.list
      expect(ret).to eq([{:alias=>"bob", :rid=>:abcdefg}])
    end

    it "gets item" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"info",
                              :arguments=>["FFFFFFFFFF", {}]} ]}).
        to_return(body: [{:id=>1, :status=>"ok", :result=>{:comments=>[]}}])

      ret = @prd.fetch("FFFFFFFFFF")
      expect(ret).to eq({:comments=>[]})
    end
  end

  context "Modifying" do
    it "Drops RID" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"drop",
                              :arguments=>["abcdefg"]} ]}).
        to_return(body: [{:id=>1, :status=>"ok"}])

      ret = @prd.remove("abcdefg")
      expect(ret).to be_nil
    end

    it "Creates" do
      frid = "ffffffffffffffffffffffffffffffffffffffff"
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"create",
                              :arguments=>["dataport",{
                                :format=>"string",
                                :name=>"bob",
                                :retention=>{
                                  :count=>1,
                                  :duration=>"infinity"
                                }
                              }]} ]}).
        to_return(body: [{:id=>1, :status=>"ok", :result=>frid}])

      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"map",
                              :arguments=>["alias", frid, "bob"]} ]}).
        to_return(body: [{:id=>1, :status=>"ok"}])

      ret = @prd.create("bob")
      expect(ret).to be_nil
    end
  end

  context "uploads" do
    it "replacing" do
      frid = "ffffffffffffffffffffffffffffffffffffffff"
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"drop",
                              :arguments=>[frid]} ]}).
        to_return(body: [{:id=>1, :status=>"ok"}])

      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"create",
                              :arguments=>["dataport",{
                                :format=>"string",
                                :name=>"bob",
                                :retention=>{
                                  :count=>1,
                                  :duration=>"infinity"
                                }
                              }]} ]}).
        to_return(body: [{:id=>1, :status=>"ok", :result=>frid}])

      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"map",
                              :arguments=>["alias", frid, "bob"]} ]}).
        to_return(body: [{:id=>1, :status=>"ok"}])

      @prd.upload(nil, {:alias=>"bob", :format=>"string", :rid=>frid}, true)
    end

    it "creating" do
      frid = "ffffffffffffffffffffffffffffffffffffffff"
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"create",
                              :arguments=>["dataport",{
                                :format=>"string",
                                :name=>"bob",
                                :retention=>{
                                  :count=>1,
                                  :duration=>"infinity"
                                }
                              }]} ]}).
        to_return(body: [{:id=>1, :status=>"ok", :result=>frid}])

      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"map",
                              :arguments=>["alias", frid, "bob"]} ]}).
        to_return(body: [{:id=>1, :status=>"ok"}])

      @prd.upload(nil, {:alias=>"bob", :format=>"string"}, false)
    end
  end

  context "compares" do
    before(:example) do
      @iA = {:alias=>"data",
             :format=>"string",
             }
      @iB = {:alias=>"data",
             :format=>"string",
             }
    end
    it "same" do
      ret = @prd.docmp(@iA, @iB)
      expect(ret).to eq(false)
    end

    it "different alias" do
      iA = @iA.merge({:alias=>"bob"})
      ret = @prd.docmp(iA, @iB)
      expect(ret).to eq(true)
    end

    it "different format" do
      iA = @iA.merge({:format=>"integer"})
      ret = @prd.docmp(iA, @iB)
      expect(ret).to eq(true)
    end
  end


  context "Lookup functions" do
    it "gets local name" do
      ret = @prd.tolocalname({ :method=>'get', :path=>'one/two/three' }, nil)
      expect(ret).to eq('')
    end

    it "gets synckey" do
      ret = @prd.synckey({ :alias=>'get' })
      expect(ret).to eq("get")
    end

    it "tolocalpath is into" do
      ret = @prd.tolocalpath('a/path/', {:id=>'cors'})
      expect(ret).to eq('a/path/')
    end
  end

  context "local resources" do
    before(:example) do
      # pull over test file.
      FileUtils.mkpath(File.dirname($cfg['location.resources']))
      lb = (@testdir + 'spec/fixtures/product_spec_files/lightbulb-1p.yaml').realpath
      @spec_path = $cfg['location.resources']
      FileUtils.copy(lb.to_path, @spec_path)
    end

    context "gets local items" do
      it "is there" do
        ret = @prd.localitems(@spec_path)
        expect(ret).to eq([
          {:alias=>"state", :format=>"integer", :initial=>0},
          {:alias=>"temperature", :format=>"float", :initial=>0},
          {:alias=>"uptime", :format=>"integer", :initial=>0},
          {:alias=>"humidity", :format=>"float", :initial=>0}
        ])
      end

      it "is missing" do
        expect(@prd).to receive(:warning).once.with("Skipping missing specs/resources.yaml-h")
        ret = @prd.localitems(@spec_path + '-h')
        expect(ret).to eq([])
      end

      it "isn't a file" do
        expect(@prd).to receive(:warning).once.with("Cannot read from specs/resources.yaml-h")
        FileUtils.mkpath(@spec_path + '-h')
        ret = @prd.localitems(@spec_path + '-h')
        expect(ret).to eq([])
      end

      it "has wrong format" do
        File.open(@spec_path + '-h', 'w') do |io|
          io << ['a','b','c'].to_yaml
        end
        expect(@prd).to receive(:warning).once.with("Unexpected data in specs/resources.yaml-h")
        ret = @prd.localitems(@spec_path + '-h')
        expect(ret).to eq([])
      end
    end
  end

  context "downloads" do
    before(:example) do
      FileUtils.mkpath(File.dirname($cfg['location.resources']))
      @lb = (@testdir + 'spec/fixtures/product_spec_files/lightbulb-1p.yaml').realpath
      @spec_path = Pathname.new($cfg['location.resources'])
    end

    it "when nothing is there" do
      frid = "FFFFFFFFFF"
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"info",
                              :arguments=>[frid, {}]} ]}).
        to_return(body: [{:id=>1, :status=>"ok", :result=>{:description=>{:format=>'integer'}}}])

      @prd.download(@spec_path, {:rid=>frid, :alias=>'state'})

      data = nil
      @spec_path.open{|io| data = YAML.load(io)}
      expect(data).to eq({"resources"=>[{"alias"=>"state", "format"=>"integer"}]})
    end

    it "merging into existing file" do
      FileUtils.copy(@lb.to_path, @spec_path)
      frid = "FFFFFFFFFF"
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"info",
                              :arguments=>[frid, {}]} ]}).
        to_return(body: [{:id=>1, :status=>"ok", :result=>{:description=>{:format=>'integer'}}}])

      @prd.download(@spec_path, {:rid=>frid, :alias=>'state'})
      #FileUtils.copy_stream(@spec_path, $stdout)
      #expect(FileUtils.cmp(@spec_path.to_path, @lb.to_path)).to be true

      data = nil
      @spec_path.open{|io| data = YAML.load(io)}
      expect(data).to eq({"resources"=>[
        {"alias"=>"temperature", "format"=>"float", "initial"=>0},
        {"alias"=>"uptime", "format"=>"integer", "initial"=>0},
        {"alias"=>"humidity", "format"=>"float", "initial"=>0},
        {"alias"=>"state", "format"=>"integer"}
      ]})
    end

  end

  context "removes local items" do
    before(:example) do
      # pull over test file.
      FileUtils.mkpath(File.dirname($cfg['location.resources']))
      @lb = (@testdir + 'spec/fixtures/product_spec_files/lightbulb-1p.yaml').realpath
      @spec_path = $cfg['location.resources']
      FileUtils.copy(@lb.to_path, @spec_path)
      @spec_path = Pathname.new(@spec_path)
    end

    it "it exists and has item" do
      @prd.removelocal(@spec_path, {:alias=>"state"})
      lbns = (@testdir + 'spec/fixtures/product_spec_files/lightbulb-no-state.yaml').realpath
      expect(lbns.read).to eq(@spec_path.read)
    end

    it "it exists and does not have item" do
      @prd.removelocal(@spec_path, {:alias=>"ThisAliasDoesNotExistInHere"})
      # nothing changed
      expect(@lb.read).to eq(@spec_path.read)
    end
  end
end

#  vim: set ai et sw=2 ts=2 :
