require "dotenv/load"

configure do
  enable :sessions

  use Rack::Session::Cookie, secret: SecureRandom.hex(64)
  use Rack::Protection::AuthenticityToken, allow_if: ->(env) { env["request_path"] != "/auth" }

  use OmniAuth::Builder do
    provider :github, ENV.fetch("GITHUB_CLIENT_ID"), ENV.fetch("GITHUB_CLIENT_SECRET"), scope: "user"
  end
end

helpers do
  def render_data(data)
    if request.accept?("application/json")
      content_type :json
      data.to_json
    else
      content_type "application/x-www-form-urlencoded"
      URI.encode_www_form(data)
    end
  end
end

get "/" do
  "Authmenace IndieAuth authorization and token server"
end

get "/auth" do
  # Check all required params have been provided
  %w[me client_id redirect_uri state].each do |param|
    unless params.key?(param) && !params[param].empty?
      halt 400, "Authorization request is missing the '#{param}' parameter."
    end
  end

  # Set up session
  session[:redirect_uri] = params[:redirect_uri]
  session[:client_id] = params[:client_id]
  session[:me] = params[:me]
  session[:state] = params[:state]
  session[:scope] = params[:scope] || ""

  erb :auth
end

get "/auth/github/callback" do
  # Ensure the expected user has been authenticated
  username = request.env["omniauth.auth"]["info"]["nickname"]
  unless username == ENV.fetch("GITHUB_USERNAME")
    halt 401, "GitHub username (#{username}) does not match expected username."
  end

  halt 500, "Session has expired during authorization. Please try again." if session.empty?

  # Generate a JWT auth code
  now = Time.now.to_i
  key = OpenSSL::PKey::EC.new(ENV.fetch("JWT_PRIVATE_KEY"))
  payload = {
    scope: session[:scope],
    redirect_uri: session[:redirect_uri],
    exp: now + (4 * 3600), # 1 hour
    iss: "Authmenace (auth)",
    aud: session[:client_id],
    jti: Digest::MD5.hexdigest([key, now].join(":").to_s),
    iat: now,
    sub: session[:me]
  }
  token = JWT.encode(payload, key, "ES256")

  query = URI.encode_www_form({
                                code: token,
                                state: session[:state],
                                me: session[:me]
                              })
  url = "#{session[:redirect_uri]}?#{query}"

  session.clear

  logger.info "Callback is redirecting to #{url}"
  redirect url
end

get "/auth/failure" do
  params[:message]
end

post "/auth" do
  key = OpenSSL::PKey::EC.new(ENV.fetch("JWT_PRIVATE_KEY"))

  decoded_token = JWT.decode(params[:code], key, true, {
                               algorithm: "ES256",
                               iss: "Authmenace (auth)",
                               verify_iss: true,
                               verify_iat: true
                             })

  render_data({ me: decoded_token.first["sub"], scope: decoded_token.first["scope"] })
rescue JWT::ExpiredSignature, JWT::ImmatureSignature, JWT::InvalidIssuerError,
       JWT::InvalidAudError, JWT::InvalidJtiError, JWT::InvalidIatError, JWT::InvalidSubError
  # Something is wrong with the JWT
  halt 400, "The supplied JWT is not valid."
end

post "/token" do
  # Check all required params have been provided
  %w[code me redirect_uri client_id].each do |param|
    unless params.key?(param) && !params[param].empty?
      halt 400, "Authorization request is missing the '#{param}' parameter."
    end
  end

  key = OpenSSL::PKey::EC.new(ENV.fetch("JWT_PRIVATE_KEY"))

  # Verify the JWT auth code
  decoded_token = JWT.decode(params[:code], key, true, {
                               algorithm: "ES256",
                               iss: "Authmenace (auth)",
                               verify_iss: true,
                               aud: params[:client_id],
                               verify_aud: true,
                               verify_iat: true,
                               sub: params[:me],
                               verify_sub: true
                             })

  # Generate a new JWT access token
  now = Time.now.to_i
  payload = {
    scope: decoded_token.first["scope"],
    redirect_uri: decoded_token.first["redirect_uri"],
    exp: now + (4 * 3600 * 24 * 30), # 30 days
    iss: "Authmenace (token)",
    aud: decoded_token.first["aud"],
    jti: Digest::MD5.hexdigest([key, now].join(":").to_s),
    iat: now,
    sub: decoded_token.first["sub"]
  }
  access_token = JWT.encode(payload, key, "ES256")

  render_data({
                access_token:,
                me: decoded_token.first["sub"],
                scope: decoded_token.first["scope"]
              })
rescue JWT::ExpiredSignature, JWT::ImmatureSignature, JWT::InvalidIssuerError,
       JWT::InvalidAudError, JWT::InvalidJtiError, JWT::InvalidIatError, JWT::InvalidSubError
  # Something is wrong with the JWT
  halt 400, "The supplied JWT is not valid."
end

get "/token" do
  access_token = request.env["HTTP_AUTHORIZATION"] || params["access_token"] || ""
  access_token.sub!(/^Bearer /, "")
  halt 400, "Access token was not found in request header or body." if access_token.empty?

  key = OpenSSL::PKey::EC.new(ENV.fetch("JWT_PRIVATE_KEY"))

  decoded_token = JWT.decode(access_token, key, true, {
                               algorithm: "ES256",
                               iss: "Authmenace (token)",
                               verify_iss: true,
                               verify_iat: true
                             })

  render_data({
                me: decoded_token.first["sub"],
                scope: decoded_token.first["scope"],
                client_id: decoded_token.first["aud"]
              })
rescue JWT::ExpiredSignature, JWT::ImmatureSignature, JWT::InvalidIssuerError,
       JWT::InvalidAudError, JWT::InvalidJtiError, JWT::InvalidIatError, JWT::InvalidSubError
  # Something is wrong with the JWT
  halt 400, "The supplied JWT is not valid."
end
