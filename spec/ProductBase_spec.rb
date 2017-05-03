require 'MrMurano/version'
require 'MrMurano/Product'
require '_workspace'

RSpec.describe MrMurano::OnePlatform::Base, "#product_base" do
  include_context "WORKSPACE"
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $project = MrMurano::ProjectFile.new
    $project.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['product.id'] = 'XYZ'

    @prd = MrMurano::OnePlatform::Base.new
    allow(@prd).to receive(:token).and_return("TTTTTTTTTT")
  end

  it "initializes" do
    uri = @prd.endPoint('/')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/product/XYZ/")
  end

  it "can get" do
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "Fooo")

    ret = @prd.get('/')
    expect(ret).to eq("Fooo")
  end

  it "returns hash when getting empty body" do
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "")

    ret = @prd.get('/')
    expect(ret).to eq({})
  end

  it "auto parses JSON responses" do
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: %{{"first": "str", "sec":[1,2,3], "third":{"a":"b"}}})

    ret = @prd.get('/')
    expect(ret).to eq({:sec=>[1,2,3],:third=>{:a=>'b'},:first=>'str'})
  end

  it "can post nothing" do
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "")
    ret = @prd.post('/')
    expect(ret).to eq({})
  end

  it "can post json" do
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'},
          body: {:this=>"is", :a=>'test'}).
      to_return(body: "")
    ret = @prd.post('/', {:this=>"is", :a=>'test'})
    expect(ret).to eq({})
  end

  it "can post form data" do
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/x-www-form-urlencoded'},
          body: "this=is&a=test").
      to_return(body: "")
    ret = @prd.postf('/', {:this=>"is", :a=>'test'})
    expect(ret).to eq({})
  end

  it "can put nothing" do
    stub_request(:put, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "")
    ret = @prd.put('/')
    expect(ret).to eq({})
  end

  it "can put json" do
    stub_request(:put, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'},
          body: {:this=>"is", :a=>'test'}).
      to_return(body: "")
    ret = @prd.put('/', {:this=>"is", :a=>'test'})
    expect(ret).to eq({})
  end

  it "can delete" do
    stub_request(:delete, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "")
    ret = @prd.delete('/')
    expect(ret).to eq({})
  end

end

#  vim: set ai et sw=2 ts=2 :
