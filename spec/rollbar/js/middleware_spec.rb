require 'spec_helper'
require 'rollbar/js/middleware'

describe Rollbar::Js::Middleware do
  subject { described_class.new(app, config) }

  let(:env) { {} }
  let(:config) { {} }
  let(:app) do
    proc do |_|
      [status, headers, body]
    end
  end
  let(:html) do
    <<-END
<html>
  <head>
    <link rel="stylesheet" href="url" type="text/css" media="screen" />
    <script type="text/javascript" src="foo"></script>
  </head>
  <body>
    <h1>Testing the middleware</h1>
  </body>
</html>
END
  end
  let(:snippet) { 'THIS IS THE SNIPPET' }
  let(:content_type) { 'text/html' }

  before do
    allow(subject).to receive(:js_snippet).and_return(snippet)
  end

  shared_examples "doesn't add the snippet or config", :add_js => false do
    it "doesn't add the snippet or config" do
      res_status, res_headers, response = subject.call(env)
      new_body = response.join

      expect(new_body).not_to include(snippet)
      expect(new_body).not_to include(config[:options].to_json)
      expect(new_body).to be_eql(body.join)
      expect(res_status).to be_eql(status)
      expect(res_headers['Content-Type']).to be_eql(content_type)
    end
  end

  describe '#call' do
    context 'with enabled config' do
      let(:config) do
        {
          :enabled => true,
          :options => { :foo => :bar }
        }
      end

      context 'having a html 200 response' do
        let(:body) { [html] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end

        it 'adds the config and the snippet to the response' do
          res_status, res_headers, response = subject.call(env)
          new_body = response.body.join

          expect(new_body).to include(snippet)
          expect(new_body).to include(config[:options].to_json)
          expect(res_status).to be_eql(status)
          expect(res_headers['Content-Type']).to be_eql(content_type)
        end
      end

      context 'having a html 200 response without head', :add_js => false do
        let(:body) { ['foobar'] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end
      end

      context 'having a html 302 response', :add_js => false do
        let(:body) { ['foobar'] }
        let(:status) { 302 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end
      end

      context 'having the js already injected key in env', :add_js => false do
        let(:body) { ['foobar'] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end
        let(:env) do
          { described_class::JS_IS_INJECTED_KEY => true }
        end
      end

      context 'having an attachment', :add_js => false do
        let(:content_type) { 'text/plain' }
        let(:body) { ['foobar'] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Disposition' => 'attachment',
            'Content-Type' => content_type
          }
        end
      end

      context 'with an exception raised while adding the js', :add_js => false do
        let(:body) { [html] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end

        before do
          allow(subject).to receive(:add_js).and_raise(StandardError.new)
        end
      end
    end

    context 'having the config disabled', :add_js => false do
      let(:body) { ['foobar'] }
      let(:status) { 302 }
      let(:headers) do
        { 'Content-Type' => content_type }
      end
      let(:config) do
        {
          :enabled => false,
          :options => { :foo => :bar }
        }
      end
    end

    context 'if the app raises' do
      let(:exception) { StandardError.new }
      let(:app) do
        proc do |_|
          raise exception
        end
      end

      it 'propagates the exception' do
        expect do
          app.call(env)
        end.to raise_exception(exception)
      end
    end
  end
end
