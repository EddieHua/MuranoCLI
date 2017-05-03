require 'MrMurano/version'
require 'MrMurano/Config'
require 'MrMurano/OnePlatform'
require '_workspace'

RSpec.describe MrMurano::OnePlatform::Product, "#product" do
  include_context "WORKSPACE"
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['product.id'] = 'XYZ'

    @prd = MrMurano::OnePlatform::Product.new
    allow(@prd).to receive(:token).and_return("TTTTTTTTTT")
  end

  it "returns info" do
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/info").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: {
         "id"=> "<id>",
         "bizid"=>"<bizid>",
         "label"=> "<label>",
         "endpoint"=> "<endpoint>",
         "rid"=> "<rid>",
         "modelrid"=> "<rid>",
         "resources"=> [{
           "alias"=> "<alias>",
           "format"=> "<format>",
           "rid"=> "<rid>"
         }]
       }.to_json)

      ret = @prd.info()
      expect(ret).to eq({
         :id=> "<id>",
         :bizid=>"<bizid>",
         :label=> "<label>",
         :endpoint=> "<endpoint>",
         :rid=> "<rid>",
         :modelrid=> "<rid>",
         :resources=> [{
           :alias=> "<alias>",
           :format=> "<format>",
           :rid=> "<rid>"
         }]
       })
  end

  it "Can list devices" do
    stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/device/").
      with(query: {'limit'=>50, 'offset'=>0}).
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: [{:sn=>"009",
                        :status=>"activated",
                        :rid=>"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"}].to_json)
    ret = @prd.list()
    expect(ret).to eq([{:sn=>"009",
                        :status=>"activated",
                        :rid=>"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"}])
  end

  it "can enable" do
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/device/42").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: {:sn=> "<sn>", :status=> "<status>", :rid=> "<devicerid>"}.to_json)

    ret = @prd.enable(42)
    expect(ret).to eq({:sn=> "<sn>", :status=> "<status>", :rid=> "<devicerid>"})
  end

  it "can update definition" do
    rbody = [
      {:alias=>"state",
       :rid=>"755857c8df71bb0cfe82773b8ba35236ae70fd77"},
      {:alias=>"temperature",
       :rid=>"6eee2542ec5f1dc7d27e46b90f3dc054a8dadab7"},
      {:alias=>"uptime",
       :rid=>"196c2077557c1924b0d8b75c6c1f6df104f251a6"},
      {:alias=>"humidity",
       :rid=>"49e7d53b6ed3c80ece619ac4878fbdb0bb95aa80"}
    ]
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/definition").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'text/yaml'}).
      to_return(body: rbody.to_json)

    # Open test file sepc.yaml
    pth = (@testdir + 'spec/fixtures/product_spec_files/lightbulb.yaml').realpath
    ret = @prd.update(pth)
    expect(ret).to eq(rbody)
  end

  it "can write" do
    stub_request(:post, "https://bizapi.hosted.exosite.io/api:1/product/XYZ/write/42").
      with(headers: {'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: {:temp=> "ok", :humid=> "ok"}.to_json)

    ret = @prd.write(42, {:temp=>78, :humid=>50})
    expect(ret).to eq({:temp=> "ok", :humid=> "ok"})
  end

  context "converting a specFile" do
    it "can convert a file" do
      epth = (@testdir + 'spec/fixtures/product_spec_files/gwe.exoline.spec.yaml').realpath
      mpth = (@testdir + 'spec/fixtures/product_spec_files/gwe.murano.spec.yaml').realpath
      out = @prd.convert(epth)
      want = mpth.read

      expect(out).to eq(want)
    end

    it "can convert stdin" do
      epth = (@testdir + 'spec/fixtures/product_spec_files/gwe.exoline.spec.yaml').realpath
      mpth = (@testdir + 'spec/fixtures/product_spec_files/gwe.murano.spec.yaml').realpath
      epth.open do |fin|
        begin
          $stdin = fin
          out = @prd.convert('-')
          want = mpth.read

          expect(out).to eq(want)
        ensure
          $stdin = STDIN
        end
      end
    end

    it "converts a fully featured exoline spec file" do
      epth = (@testdir + 'spec/fixtures/product_spec_files/example.exoline.spec.yaml').realpath
      mpth = (@testdir + 'spec/fixtures/product_spec_files/example.murano.spec.yaml').realpath
      out = @prd.convert(epth)
      want = mpth.read

      expect(out).to eq(want)
    end

    it "raises when not an exoline spec" do
      expect {
        pth = @testdir + 'spec/fixtures/product_spec_files/example.murano.spec.yaml'
        @prd.convert(pth.realpath)
      }.to raise_exception('No dataports section found, or not an array')
    end
  end

end

#  vim: set ai et sw=2 ts=2 :
