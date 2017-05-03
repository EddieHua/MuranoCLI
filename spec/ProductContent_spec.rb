require 'MrMurano/version'
require 'MrMurano/Config'
require 'MrMurano/Product'
require '_workspace'

RSpec.describe MrMurano::ProductContent, "#product_content" do
  include_context "WORKSPACE"
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $project = MrMurano::ProjectFile.new
    $project.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['product.id'] = 'XYZ'

    @prd = MrMurano::ProductContent.new
    allow(@prd).to receive(:token).and_return("TTTTTTTTTT")

    @urlroot = "https://bizapi.hosted.exosite.io/api:1/product/XYZ/proxy/provision/manage/content/XYZ"
  end

  it "lists nothing" do
    stub_request(:get, @urlroot + "/").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "")

    ret = @prd.list
    expect(ret).to eq([])
  end

  it "lists something" do
    stub_request(:get, @urlroot + "/").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "one\ntwo\nthree\n")

    ret = @prd.list
    expect(ret).to eq(['one','two','three'])
  end

  it "lists something for identifier" do
    stub_request(:get, @urlroot + "/?sn=12").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "one\ntwo\nthree\n")

    ret = @prd.list_for('12')
    expect(ret).to eq(['one','two','three'])
  end

  it "creates an item" do
    stub_request(:post, @urlroot + "/").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/x-www-form-urlencoded'}).
      with(body: {'id'=>'testFor', 'meta'=> 'some meta'}).
      to_return(status: 205)

    ret = @prd.create("testFor", "some meta")
    expect(ret).to eq({})
  end

  it "removes an item" do
    stub_request(:post, @urlroot + "/").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/x-www-form-urlencoded'}).
      with(body: {'id'=>'testFor', 'delete'=>'true'}).
      to_return(status: 205)

    ret = @prd.remove("testFor")
    expect(ret).to eq({})
  end

  it "gets info for content" do
    stub_request(:get, @urlroot + "/testFor").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "text/plain,42,123456789,test meta,false")

    ret = @prd.info("testFor")
    expect(ret).to eq([['text/plain','42','123456789','test meta','false']])
  end

  it "gets info for missing content" do
    stub_request(:get, @urlroot + "/testFor").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(status: 404, body: "")

    ret = @prd.info("testFor")
    expect(ret).to be_nil
  end

  it "removes content" do
    stub_request(:delete, @urlroot + "/testFor").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(status: 205)

    ret = @prd.remove_content("testFor")
    expect(ret).to eq({})
  end

  it "uploads content data" do
    pth = (@testdir + 'spec/fixtures/product_spec_files/lightbulb.yaml').realpath
    size = FileTest.size(pth.to_path)
    stub_request(:post, @urlroot + "/testFor").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>/text\/(x-)?yaml/,
                      'Content-Length' => size
      }).
      to_return(status: 205)

    ret = @prd.upload('testFor', pth.to_path)
    expect(ret).to eq({})
  end

  context "downloads content" do
    it "to block" do
      stub_request(:get, @urlroot + "/testFor?download=true").
        with(headers: {'Authorization'=>'token TTTTTTTTTT',
                       'Content-Type'=>'application/json'}).
                       to_return(body: "short and sweet")

      data = ""
      @prd.download('testFor') {|chunk| data << chunk}
      expect(data).to eq("short and sweet")
    end

    it "to stdout" do
      stub_request(:get, @urlroot + "/testFor?download=true").
        with(headers: {'Authorization'=>'token TTTTTTTTTT',
                       'Content-Type'=>'application/json'}).
                       to_return(body: "short and sweet")

      begin
        old_stdout = $stdout
        $stdout = StringIO.new('','w')
        @prd.download('testFor')
        expect($stdout.string).to eq("short and sweet")
      ensure
        $stdout = old_stdout
      end
    end

    it "but error" do
      stub_request(:get, @urlroot + "/testFor?download=true").
        with(headers: {'Authorization'=>'token TTTTTTTTTT',
                       'Content-Type'=>'application/json'}).
                       to_return(status:404, body: "{}")

      data = ""
      expect(@prd).to receive(:error).once
      @prd.download('testFor') {|chunk| data << chunk}
      expect(data).to eq("")

    end
  end

end

#  vim: set ai et sw=2 ts=2 :
