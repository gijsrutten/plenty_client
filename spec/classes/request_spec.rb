require 'spec_helper'

RSpec.describe PlentyClient::Request::ClassMethods do
  let(:ic) { Class.new { include PlentyClient::Request } }

  before(:each) do
    PlentyClient::Config.site_url = 'https://www.example.com'
  end

  def stub_api_tokens(access_token: 'foobar', expiry_date: Time.now + 86400,
                      refresh_token: 'foobar')
    PlentyClient::Config.access_token = access_token
    PlentyClient::Config.refresh_token = refresh_token
    PlentyClient::Config.expiry_date = expiry_date
  end

  describe 'requests' do
    describe '#request' do
      before(:each) do
        stub_api_tokens
        stub_request(:any, /example/)
          .to_return(status: 200, body: '{}', headers: {})
      end

      context 'with valid arguments' do
        it 'makes a HTTP call' do
          ic.request(:post, '/index.html')
          expect(WebMock).to have_requested(:post, /example/)
        end
      end

      context 'without http_method' do
        it 'returns false' do
          response = ic.request(nil, '/index.html')
          expect(response).to be false
        end

        it 'does not make a HTTP call' do
          expect(WebMock).not_to have_requested(:any, /example/)
          ic.request(nil, '/index.html')
        end
      end

      context 'without path' do
        it 'returns false' do
          response = ic.request(:post, nil)
          expect(response).to be false
        end

        it 'does not make a HTTP call' do
          expect(WebMock).not_to have_requested(:any, /example/)
          ic.request(:post, nil)
        end
      end
    end

    describe 'wrappers for #request' do
      describe '#post' do
        it 'calls #request with :post and rest of params' do
          expect(ic).to receive(:request).with(:post, '/index.php', 'param1' => 'value1')
          ic.post('/index.php', 'param1' => 'value1')
        end
      end

      describe '#put' do
        it 'calls #request with :put and rest of params' do
          expect(ic).to receive(:request).with(:put, '/index.php', 'param1' => 'value1')
          ic.put('/index.php', 'param1' => 'value1')
        end
      end

      describe '#patch' do
        it 'calls #request with :patch and rest of params' do
          expect(ic).to receive(:request).with(:patch, '/index.php', 'param1' => 'value1')
          ic.patch('/index.php', 'param1' => 'value1')
        end
      end

      describe '#delete' do
        it 'calls #request with :delete and rest of params' do
          expect(ic).to receive(:request).with(:delete, '/index.php', 'param1' => 'value1')
          ic.delete('/index.php', 'param1' => 'value1')
        end
      end

      describe '#get' do
        context 'when called without a block' do
          context 'when called without page param' do
            it 'calls #request with :get and rest of params, merged with page: 1' do
              expect(ic).to receive(:request).with(:get, '/index.php', 'p1' => 'v1', 'page' => 1)
              ic.get('/index.php', 'p1' => 'v1')
            end
          end

          context 'when called with page param' do
            it 'calls #request with :get and unchanged params' do
              expect(ic).to receive(:request).with(:get, '/index.php', hash_including('p1' => 'v1', 'page' => 100))
              ic.get('/index.php', 'p1' => 'v1', 'page' => 100)
            end
          end
        end

        context 'when called with a block' do
          before do
            stub_request(:get, /example/)
              .to_return do |r|
              query = CGI.parse(r.uri.query)
              page = query['page'][0].to_i
              {
                body: {
                  page: page,
                  totalsCount: 3,
                  isLastPage: (page == 3),
                  entries: %w[a b c]
                }.to_json
              }
            end
          end

          it 'calls #request with get until it gets last page' do
            ic.get('/index.php', {}) do
              'Hello world'
            end
            expect(WebMock).to have_requested(:get, /example/).times(3)
          end

          it 'yields entries n times' do
            expect { |b| ic.get('/index.php', {}, &b) }.to yield_control.exactly(3).times
          end
        end
      end
    end
  end

  describe 'authentication' do
    context 'when no accessToken is present' do
      before do
        PlentyClient::Config.access_token = nil
        PlentyClient::Config.refresh_token = nil
        PlentyClient::Config.expiry_date = nil
        @login_request = stub_request(:post, /login/).to_return(body: {
          'tokenType' => 'Bearer',
          'expiresIn' => 86400,
          'accessToken' => 'foo_access_token',
          'refreshToken' => 'foo_refresh_token'
        }.to_json)
        @actual_request = stub_request(:post, /index\.html/).to_return(body: {
        }.to_json)
      end

      context 'when credentials are missing' do
        before do
          PlentyClient::Config.api_user = nil
          PlentyClient::Config.api_password = nil
        end

        it 'raises PlentyClient::Config::NoCredentials' do
          expect { ic.request(:post, '/index.html') }.to raise_exception(PlentyClient::Config::NoCredentials)
        end

        it 'does not perform login request' do
          expect(@login_request).not_to have_been_made
        end

        it 'does not perform the actual request' do
          expect(@actual_request).not_to have_been_made
        end
      end

      context 'when all credentials are present' do
        before do
          PlentyClient::Config.api_user = 'foouser'
          PlentyClient::Config.api_password = 'foopass'
        end

        it 'performs a POST request with username and password' do
          ic.request(:post, '/index.html')
          expect(@login_request).to have_been_made.once
        end

        context 'when credentials are correct' do
          before(:each) do
            ic.request(:post, '/index.html')
          end

          it 'sets Config.access_token' do
            expect(PlentyClient::Config.access_token).to eq('foo_access_token')
          end

          it 'sets Config.refresh_token' do
            expect(PlentyClient::Config.refresh_token).to eq('foo_refresh_token')
          end

          it 'sets Config.expiry_date' do
            expect(PlentyClient::Config.expiry_date.to_i).to be_within(1).of((Time.now + 86400).to_i)
          end

          it 'performs the actual request' do
            expect(@actual_request).to have_been_made.once
          end

        end

        context 'when credentials are incorrect' do
          before do
            PlentyClient::Config.api_user = 'foouser2'
            PlentyClient::Config.api_password = 'abcdef'
            @login_request = stub_request(:post, /login/).to_return(body: {
              'error' => 'invalid_credentials',
              'message' => 'The user credentials were incorrect.',
              'tokenType' => nil,
              'expiresIn' => nil,
              'accessToken' => nil,
              'refreshToken' => nil
            }.to_json)
          end

          it 'raises PlentyClient::Config::InvalidCredentials' do
            expect { ic.request(:post, '/index.html') }.to raise_exception(PlentyClient::Config::InvalidCredentials)
          end

          describe 'handling' do
            before(:each) do
              begin
                ic.request(:post, '/index.html') 
              rescue PlentyClient::Config::InvalidCredentials
              end
            end

            it 'does not perform the actual request' do
              expect(@actual_request).not_to have_been_made
            end

            it 'does not set Config.access_token' do
              expect(PlentyClient::Config.access_token).to be_nil
            end

            it 'does not set Config.refresh_token' do
              expect(PlentyClient::Config.refresh_token).to be_nil
            end

            it 'does not set Config.expiry_date' do
              expect(PlentyClient::Config.expiry_date).to be_nil
            end
          end
        end
      end
    end
  end
end