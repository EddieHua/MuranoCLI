require 'MrMurano/version'
require 'MrMurano/Config'
require 'MrMurano/OnePlatform-1P-Device'
require '_workspace'

RSpec.describe MrMurano::OnePlatform::Device, '#sn_rid tests' do
  include_context "WORKSPACE"
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $project = MrMurano::ProjectFile.new
    $project.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['product.id'] = 'XYZ'
    $cfg['product.spec'] = 'XYZ.yaml'

    @prd = MrMurano::OnePlatform::Device.new
    allow(@prd).to receive(:token).and_return("TTTTTTTTTT")
    @mrp = instance_double("MrMurano::Product")
    allow(MrMurano::OnePlatform::Product).to receive(:new).and_return(@mrp)
  end

  it "gets rid from sn" do
    expect(@mrp).to receive(:list).once.and_return([
      {:sn=>"12",
       :status=>"activated",
       :rid=>"77cbf643ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"}])
    ret = @prd.sn_rid("12")
    expect(ret).to eq("77cbf643ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ")
  end

  it "gets rid from sn on page two" do
    expect(@mrp).to receive(:list).twice.and_return(
      [{:sn=>"14",
       :status=>"notactivated"}],
      [{:sn=>"12",
       :status=>"activated",
       :rid=>"77cbf643ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"}])

    ret = @prd.sn_rid("12")
    expect(ret).to eq("77cbf643ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ")
  end

  it "doesn't find the sn" do
    expect(@mrp).to receive(:list).twice.and_return(
      [{:sn=>"14",
       :status=>"notactivated"}],
      [])

    expect {
      @prd.sn_rid("12")
    }.to raise_error "Identifier Not Found: 12"
  end

  it "gets model_rid" do
    expect(@mrp).to receive(:info).once.and_return({:modelrid=>"1234567890"})
    ret = @prd.model_rid
    expect(ret).to eq("1234567890")
  end
  it "raises with bad model_rid" do
    expect(@mrp).to receive(:info).once.and_return({:mid=>"1234567890"})
    expect {
      @prd.model_rid
    }.to raise_error(/^Bad info; .*/)
  end
end

RSpec.describe MrMurano::OnePlatform::Device do
  include_context "WORKSPACE"
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $project = MrMurano::ProjectFile.new
    $project.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['product.id'] = 'XYZ'
    $cfg['product.spec'] = 'XYZ.yaml'

    @prd = MrMurano::OnePlatform::Device.new
    allow(@prd).to receive(:token).and_return("TTTTTTTTTT")
    allow(@prd).to receive(:sn_rid).and_return("LLLLLLLLLL")
  end

  it "initializes" do
    uri = @prd.endPoint('')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process")
  end

  it "gets info" do
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
      with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                  :calls=>[{:id=>1,
                            :procedure=>"info",
                            :arguments=>["LLLLLLLLLL", {}]} ]}).
    to_return(body: [{:id=>1, :status=>"ok", :result=>{:comments=>[]}}])

    ret = @prd.info("12")
    expect(ret).to eq({:comments=>[]})
  end

  it "lists resources" do
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
      with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                  :calls=>[{:id=>1,
                            :procedure=>"info",
                            :arguments=>["LLLLLLLLLL", {}]} ]}).
    to_return(body: [{:id=>1, :status=>"ok", :result=>{:aliases=>{
      :s2143rt4regf=>["one"],:njilh32o78rnq=>["two"]}}}])

    ret = @prd.list("12")
    expect(ret).to eq({"one"=>"s2143rt4regf", "two"=>"njilh32o78rnq"})
  end

  context "reads resources" do
    it "single" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"read",
                              :arguments=>[{"alias"=>"one"}, {}]} ]}).
      to_return(body: [{:id=>1, :status=>"ok", :result=>[ [12345678,10] ]}])
      ret = @prd.read("12", "one")
      expect(ret).to eq([10])
    end

    it "multiple" do
      stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
        with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                    :calls=>[{:id=>1,
                              :procedure=>"read",
                              :arguments=>[{"alias"=>"two"}, {}]},
                             {:id=>2,
                              :procedure=>"read",
                              :arguments=>[{"alias"=>"three"}, {}]},
                             {:id=>3,
                              :procedure=>"read",
                              :arguments=>[{"alias"=>"one"}, {}]},
      ]}).
      to_return(body: [
        {:id=>1, :status=>"ok", :result=>[ [12345678,10] ]},
        {:id=>2, :status=>"ok", :result=>[ [12345678,15] ]},
        {:id=>3, :status=>"ok", :result=>[ [12345678,20] ]},
      ])
      ret = @prd.read("12", ["two","three","one"])
      expect(ret).to eq([10,15,20])
    end

  end

  it "gets tree info for device" do
    # this makes three https calls, info on root, info and read on children

    # root info.
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
      with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                  :calls=>[{:id=>1,
                            :procedure=>"info",
                            :arguments=>["LLLLLLLLLL", {}]} ]}).
    to_return(body: [{:id=>1, :status=>"ok", :result=>{:aliases=>{
      :s2143rt4regf=>["one"],:njilh32o78rnq=>["two"]}}}])

    # children info
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
      with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                  :calls=>[{:id=>1,
                            :procedure=>"info",
                            :arguments=>["s2143rt4regf", {}]},
                           {:id=>2,
                            :procedure=>"info",
                            :arguments=>["njilh32o78rnq", {}]}
    ]}).
    to_return(body: [
      {:id=>1, :status=>"ok", :result=>{:basic=>{:type=>"dataport"}}},
      {:id=>2, :status=>"ok", :result=>{:basic=>{:type=>"dataport"}}}
    ])

    # children read
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/onep:v1/rpc/process").
      with(body: {:auth=>{:client_id=>"LLLLLLLLLL"},
                  :calls=>[{:id=>1,
                            :procedure=>"read",
                            :arguments=>["s2143rt4regf", {}]},
                           {:id=>2,
                            :procedure=>"read",
                            :arguments=>["njilh32o78rnq", {}]},
    ]}).
    to_return(body: [
      {:id=>1, :status=>"ok", :result=>[ [12345678,10] ]},
      {:id=>2, :status=>"ok", :result=>[ [12345678,15] ]},
    ])

    ret = @prd.twee('12')
    expect(ret).to eq({:children=>[{:basic=>{:type=>"dataport"},
                                    :rid=>:s2143rt4regf, :alias=>"one", :value=>10},
                                    {:basic=>{:type=>"dataport"},
                                     :rid=>:njilh32o78rnq, :alias=>"two",
                                     :value=>15}]})
  end

end

#  vim: set ai et sw=2 ts=2 :
