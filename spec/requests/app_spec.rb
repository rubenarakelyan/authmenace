RSpec.describe "App" do
	def app
		Sinatra::Application
	end

	describe "GET /" do
		subject(:page) { get "/" }

		it "returns a page with introductory text" do
			page
			expect(last_response.body).to include("To sign in, visit an IndieAuth-enabled website and enter <code>http://example.org</code> as the domain.")
		end
	end

	describe "GET /auth" do
		subject(:page) { get "/auth?#{params}" }

		context "when no params are provided" do
			let(:params) { "" }

			it "returns an error message" do
				page
				expect(last_response.body).to include("Authorization request is missing the 'me' parameter.")
			end
		end

		context "when the correct params are provided" do
			let(:params) { "me=http://my.domain.example.com/&client_id=http://bigcorp.example.net/&redirect_uri=http://bigcorp.example.net/redirect&state=random+string&scope=some_perm" }

			it "returns a confirmation message" do
				page
				expect(last_response.body).to include("<p><strong><code>http://bigcorp.example.net/</code></strong> is attempting to sign in using <code>http:&#x2F;&#x2F;my.domain.example.com&#x2F;</code>.</p>")
				expect(last_response.body).to include("<p>The following permissions are being sought: <code>some_perm</code>.</p>")
			end
		end
	end

	describe "GET /auth/github/callback" do
		subject(:page) { get "/auth/github/callback" }

		context "when called with an incorrect username" do
			before do
				allow(ENV).to receive(:fetch).and_call_original
				allow(ENV).to receive(:fetch).with("GITHUB_USERNAME").and_return("fakeuser")
			end

			it "returns an error message" do
				page
				expect(last_response.body).to include("GitHub username (mockuser) does not match expected username.")
			end
		end

		context "when called with the correct username" do
			it "generates a JWT and redirects to the requestor" do
				# Create session to use later
				get "/auth?me=http://my.domain.example.com/&client_id=http://bigcorp.example.net/&redirect_uri=http://bigcorp.example.net/redirect&state=random+string&scope=some_perm"
				page
				expect(last_response.status).to eq(302)
				expect(last_response.location).to match(/^http:\/\/bigcorp\.example\.net\/redirect\?code=(.+)&state=random\+string&me=http%3A%2F%2Fmy\.domain\.example\.com%2F$/)
			end
		end
	end

	describe "POST /auth" do
		subject(:page) { post "/auth", { code: @token } }

		context "when called with an incorrect JWT" do
			it "returns an error message" do
				# An expired token
				@token = "eyJhbGciOiJFUzI1NiJ9.eyJzY29wZSI6bnVsbCwicmVkaXJlY3RfdXJpIjpudWxsLCJleHAiOjE3MTUwOTM2NjIsImlzcyI6IkF1dGhtZW5hY2UgKGF1dGgpIiwiYXVkIjpudWxsLCJqdGkiOiJmOWEzYWY4YmZmZTU5ODNiZTY0YzAwODQ3M2YzYWQ4ZiIsImlhdCI6MTcxNTA5MzY2Miwic3ViIjpudWxsfQ.yG8rRW4JOwai32ZvBwC_NtMcw4vvDsglw4XIbSNz4Ju9v__Aiubn-WrCpaQdqqGbxoOujKq29SZ1JveshcG38g"
				page
				expect(last_response.body).to include("The supplied JWT is not valid.")
			end
		end

		context "when called with a correct JWT" do
			it "returns a JSON response" do
				# Create session to use later
				get "/auth?me=http://my.domain.example.com/&client_id=http://bigcorp.example.net/&redirect_uri=http://bigcorp.example.net/redirect&state=random+string&scope=some_perm"
				get "/auth/github/callback"
				@token = last_response.location.match(/^http:\/\/bigcorp\.example\.net\/redirect\?code=(.+)&state=random\+string&me=http%3A%2F%2Fmy\.domain\.example\.com%2F$/)[1]
				page
				expect(JSON.parse(last_response.body)).to eq({ "me" => "http://my.domain.example.com/", "scope" => "some_perm" })
			end
		end
	end

	describe "POST /token" do
		subject(:page) { post "/token", { code: @token, me: me, redirect_uri: redirect_uri, client_id: client_id } }

		let(:me) { "http://my.domain.example.com/" }
		let(:redirect_uri) { "http://bigcorp.example.net/redirect" }
		let(:client_id) { "http://bigcorp.example.net/" }

		context "when called with a missing param" do
			let(:client_id) { "" }

			it "returns an error message" do
				@token = "test"
				page
				expect(last_response.body).to include("Authorization request is missing the 'client_id' parameter.")
			end
		end

		context "when called with an incorrect JWT" do
			it "returns an error message" do
				# An expired token
				@token = "eyJhbGciOiJFUzI1NiJ9.eyJzY29wZSI6bnVsbCwicmVkaXJlY3RfdXJpIjpudWxsLCJleHAiOjE3MTUwOTM2NjIsImlzcyI6IkF1dGhtZW5hY2UgKGF1dGgpIiwiYXVkIjpudWxsLCJqdGkiOiJmOWEzYWY4YmZmZTU5ODNiZTY0YzAwODQ3M2YzYWQ4ZiIsImlhdCI6MTcxNTA5MzY2Miwic3ViIjpudWxsfQ.yG8rRW4JOwai32ZvBwC_NtMcw4vvDsglw4XIbSNz4Ju9v__Aiubn-WrCpaQdqqGbxoOujKq29SZ1JveshcG38g"
				page
				expect(last_response.body).to include("The supplied JWT is not valid.")
			end
		end

		context "when called with an incorrect param" do
			let(:client_id) { "http://othercorp.example.net" }

			it "returns an error message" do
				# Create session to use later
				get "/auth?me=http://my.domain.example.com/&client_id=http://bigcorp.example.net/&redirect_uri=http://bigcorp.example.net/redirect&state=random+string&scope=some_perm"
				get "/auth/github/callback"
				@token = last_response.location.match(/^http:\/\/bigcorp\.example\.net\/redirect\?code=(.+)&state=random\+string&me=http%3A%2F%2Fmy\.domain\.example\.com%2F$/)[1]
				page
				expect(last_response.body).to include("The supplied JWT is not valid.")
			end
		end

		context "when called with a correct JWT" do
			it "returns a JSON response" do
				# Create session to use later
				get "/auth?me=http://my.domain.example.com/&client_id=http://bigcorp.example.net/&redirect_uri=http://bigcorp.example.net/redirect&state=random+string&scope=some_perm"
				get "/auth/github/callback"
				@token = last_response.location.match(/^http:\/\/bigcorp\.example\.net\/redirect\?code=(.+)&state=random\+string&me=http%3A%2F%2Fmy\.domain\.example\.com%2F$/)[1]
				page
				expect(JSON.parse(last_response.body)).to include("me" => "http://my.domain.example.com/", "scope" => "some_perm")
			end
		end
	end

	describe "GET /token" do
		subject(:page) { get "/token", { access_token: @access_token } }

		context "when called with an incorrect JWT" do
			it "returns an error message" do
				# An expired token
				@access_token = "eyJhbGciOiJFUzI1NiJ9.eyJzY29wZSI6bnVsbCwicmVkaXJlY3RfdXJpIjpudWxsLCJleHAiOjE3MTUwOTM2NjIsImlzcyI6IkF1dGhtZW5hY2UgKGF1dGgpIiwiYXVkIjpudWxsLCJqdGkiOiJmOWEzYWY4YmZmZTU5ODNiZTY0YzAwODQ3M2YzYWQ4ZiIsImlhdCI6MTcxNTA5MzY2Miwic3ViIjpudWxsfQ.yG8rRW4JOwai32ZvBwC_NtMcw4vvDsglw4XIbSNz4Ju9v__Aiubn-WrCpaQdqqGbxoOujKq29SZ1JveshcG38g"
				page
				expect(last_response.body).to include("The supplied JWT is not valid.")
			end
		end

		context "when called with a correct JWT" do
			it "returns a JSON response" do
				# Create session to use later
				get "/auth?me=http://my.domain.example.com/&client_id=http://bigcorp.example.net/&redirect_uri=http://bigcorp.example.net/redirect&state=random+string&scope=some_perm"
				get "/auth/github/callback"
				token = last_response.location.match(/^http:\/\/bigcorp\.example\.net\/redirect\?code=(.+)&state=random\+string&me=http%3A%2F%2Fmy\.domain\.example\.com%2F$/)[1]
				post "/token?code=#{token}&me=http://my.domain.example.com/&client_id=http://bigcorp.example.net/&redirect_uri=http://bigcorp.example.net/redirect"
				@access_token = JSON.parse(last_response.body)["access_token"]
				page
				expect(JSON.parse(last_response.body)).to eq({ "client_id" => "http://bigcorp.example.net/", "me" => "http://my.domain.example.com/", "scope" => "some_perm" })
			end
		end
	end
end
