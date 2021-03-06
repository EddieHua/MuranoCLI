require 'MrMurano/version'
require 'MrMurano/Solution-Cors'
require 'MrMurano/ProjectFile'
require 'tempfile'
require 'yaml'
require '_workspace'

RSpec.describe MrMurano::Cors do
  include_context "WORKSPACE"
  before(:example) do
    MrMurano::SyncRoot.reset
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['solution.id'] = 'XYZ'

    @srv = MrMurano::Cors.new
    allow(@srv).to receive(:token).and_return("TTTTTTTTTT")
  end

  it "initializes" do
    uri = @srv.endPoint('/')
    expect(uri.to_s).to eq("https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors/")
  end

  context "when server gives string" do
    context "fetches" do
      it "as a hash" do
        cors = {:origin=>true,
                :methods=>["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],
                :headers=>["Content-Type","Cookie","Authorization"],
                :credentials=>true}
        body = {:cors=>cors.to_json}
        stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors").
          with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                          'Content-Type'=>'application/json'}).
                          to_return(body: body.to_json)

        ret = @srv.fetch()
        expect(ret).to eq(cors)
      end
      it "as a block" do
        cors = {:origin=>true,
                :methods=>["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],
                :headers=>["Content-Type","Cookie","Authorization"],
                :credentials=>true}
        body = {:cors=>cors.to_json}
        stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors").
          with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                          'Content-Type'=>'application/json'}).
                          to_return(body: body.to_json)

        ret = ''
        loops = 0
        @srv.fetch() do |chunk|
          loops += 1
          ret << chunk
          expect(loops).to be <= 1
        end
        expect(ret).to eq(Hash.transform_keys_to_strings(cors).to_yaml)
      end
    end
  end

  context "when server gives object" do
    context "fetches" do
      it "as a hash" do
        cors = {:origin=>true,
                :methods=>["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],
                :headers=>["Content-Type","Cookie","Authorization"],
                :credentials=>true}
        body = cors
        stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors").
          with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                          'Content-Type'=>'application/json'}).
                          to_return(body: body.to_json)

        ret = @srv.fetch()
        expect(ret).to eq(cors)
      end
      it "as a block" do
        cors = {:origin=>true,
                :methods=>["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],
                :headers=>["Content-Type","Cookie","Authorization"],
                :credentials=>true}
        body = cors
        stub_request(:get, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors").
          with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                          'Content-Type'=>'application/json'}).
                          to_return(body: body.to_json)

        ret = ''
        loops = 0
        @srv.fetch() do |chunk|
          loops += 1
          ret << chunk
          expect(loops).to be <= 1
        end
        expect(ret).to eq(Hash.transform_keys_to_strings(cors).to_yaml)
      end
    end
  end

  context "uploads" do
    before(:example) do
      $project = MrMurano::ProjectFile.new
      $project.load
      @cors = {:origin=>true,
               :methods=>["HEAD","GET","POST","PUT","DELETE","OPTIONS","PATCH"],
               :headers=>["Content-Type","Cookie","Authorization"],
               :credentials=>true}
    end
    it "specified file" do
      File.open(File.join(@projectDir, 'bob.yaml'), 'w'){|io| io << @cors.to_yaml}
      stub_request(:put, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors").
        with(:body=>@cors.to_json,
             :headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: "")

      ret = @srv.upload('bob.yaml')
      expect(ret).to eq({})
    end

    it "file in $project" do
      File.open(File.join(@projectDir, 'bob.yaml'), 'w'){|io| io << @cors.to_yaml}
      $project['routes.cors'] = 'bob.yaml'
      stub_request(:put, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors").
        with(:body=>@cors.to_json,
             :headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: "")

      ret = @srv.upload()
      expect(ret).to eq({})
    end

    it "file defaults thru $project" do
      File.open(File.join(@projectDir, 'cors.yaml'), 'w'){|io| io << @cors.to_yaml}
      stub_request(:put, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors").
        with(:body=>@cors.to_json,
             :headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: "")

      ret = @srv.upload()
      expect(ret).to eq({})
    end

    it "cors in $project" do
      $project['routes.cors'] = @cors
      stub_request(:put, "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/cors").
        with(:body=>@cors.to_json,
             :headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: "")

      ret = @srv.upload()
      expect(ret).to eq({})
    end
  end

end
#  vim: set ai et sw=2 ts=2 :
