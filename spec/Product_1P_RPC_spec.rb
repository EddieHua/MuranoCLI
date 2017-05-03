require 'MrMurano/version'
require 'MrMurano/Config'
require 'MrMurano/Product-Resources'
require '_workspace'

RSpec.describe MrMurano::OnePlatform::Resources, "#1PshimTests" do
  include_context "WORKSPACE"
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['product.id'] = 'XYZ'
    $cfg['product.spec'] = 'XYZ.yaml'

    @prd = MrMurano::OnePlatform::Resources.new
    allow(@prd).to receive(:token).and_return("TTTTTTTTTT")
    allow(@prd).to receive(:model_rid).and_return("LLLLLLLLLL")
  end

  context "do_rpc" do
    # Note, do_rpc is private.
    it "Accepts an object" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: [{
        :id=>1, :status=>"ok", :result=>{}
      }])

      ret = nil
      @prd.instance_eval{ ret = do_rpc({:id=>1}) }
      expect(ret).to eq({})
    end

    it "Accepts an Array" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: [{:id=>1, :status=>"ok", :result=>{:one=>1}},
      {:id=>2, :status=>"ok", :result=>{:two=>2}}])

      ret = nil
      @prd.instance_eval{ ret = do_rpc([{:id=>1}, {:id=>2}]) }
      expect(ret).to eq({:one=>1})
      # yes it only returns first.
    end

    it "returns res if not Array" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: {:not=>'an array'}.to_json)

      ret = nil
      @prd.instance_eval{ ret = do_rpc({:id=>1}) }
      expect(ret).to eq({:not=>'an array'})
    end

    it "returns res if count less than 1" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: [])

      ret = nil
      @prd.instance_eval{ ret = do_rpc({:id=>1}) }
      expect(ret).to eq([])
    end

    it "returns res[0] if not Hash" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: ["foo"])

      ret = nil
      @prd.instance_eval{ ret = do_rpc({:id=>1}) }
      expect(ret).to eq("foo")
    end

    it "returns res[0] if not status ok" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: [{:id=>1, :status=>'error'}])

      ret = nil
      @prd.instance_eval{ ret = do_rpc({:id=>1}) }
      expect(ret).to eq({:id=>1, :status=>'error'})
    end
  end

  context "do_mrpc" do
    # Note, do_rpc is private.
    it "Accepts an object" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: [{
        :id=>1, :status=>"ok", :result=>{}
      }])

      ret = nil
      @prd.instance_eval{ ret = do_mrpc({:id=>1}) }
      expect(ret).to eq([{:id=>1, :status=>"ok", :result=>{}}])
    end

    it "Accepts an Array" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: [{:id=>1, :status=>"ok", :result=>{:one=>1}},
      {:id=>2, :status=>"ok", :result=>{:two=>2}}])

      ret = nil
      @prd.instance_eval{ ret = do_mrpc([{:id=>1}, {:id=>2}]) }
      expect(ret).to eq([{:id=>1, :status=>"ok", :result=>{:one=>1}},
                         {:id=>2, :status=>"ok", :result=>{:two=>2}}])
    end

    it "fills in all ids if missing" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: [{:id=>1, :status=>"ok", :result=>{:one=>1}},
      {:id=>2, :status=>"ok", :result=>{:two=>2}},
      {:id=>3, :status=>"ok", :result=>{:three=>3}}])

      ret = nil
      @prd.instance_eval{ ret = do_mrpc([{}, {}, {}]) }
      expect(ret).to eq([{:id=>1, :status=>"ok", :result=>{:one=>1}},
                         {:id=>2, :status=>"ok", :result=>{:two=>2}},
                         {:id=>3, :status=>"ok", :result=>{:three=>3}}])
    end

    it "fills in missing ids" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>5, :procedure=>"info"},
                             {:id=>4, :procedure=>"info"},
                             {:id=>6, :procedure=>"info"} ]}).
        to_return(body: [{:id=>5, :status=>"ok", :result=>{:one=>1}},
      {:id=>4, :status=>"ok", :result=>{:two=>2}},
      {:id=>6, :status=>"ok", :result=>{:three=>3}}])

      ret = nil
      @prd.instance_eval{ ret = do_mrpc([{:procedure=>"info"},
                                         {:procedure=>"info", :id=>4},
                                         {:procedure=>"info"}]) }
      expect(ret).to eq([{:id=>5, :status=>"ok", :result=>{:one=>1}},
                         {:id=>4, :status=>"ok", :result=>{:two=>2}},
                         {:id=>6, :status=>"ok", :result=>{:three=>3}}])
    end

    it "returns res if not Array" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: {:not=>'an array'}.to_json)

      ret = nil
      @prd.instance_eval{ ret = do_mrpc({:id=>1}) }
      expect(ret).to eq({:not=>'an array'})
    end

    it "returns res if count less than 1" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: [])

      ret = nil
      @prd.instance_eval{ ret = do_mrpc({:id=>1}) }
      expect(ret).to eq([])
    end

    it "returns res[0] if not Hash" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: ["foo"])

      ret = nil
      @prd.instance_eval{ ret = do_mrpc({:id=>1}) }
      expect(ret).to eq(["foo"])
    end

    it "returns res[0] if not status ok" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        to_return(body: [{:id=>1, :status=>'error'}])

      ret = nil
      @prd.instance_eval{ ret = do_mrpc({:id=>1}) }
      expect(ret).to eq([{:id=>1, :status=>'error'}])
    end
  end
end

#  vim: set ai et sw=2 ts=2 :
