# Authmenace

A very simple [IndieAuth](https://indieweb.org/indieauth) authorization and token endpoint heavily inspired by [Acquiescence](https://github.com/barryf/acquiescence).

## Description

Authmenace uses [JSON Web Tokens](https://jwt.io) to grant access to third-party websites that implement the IndieAuth standard. It therefore does not need any database.

It is currently used by me on the [wackomenace](https://www.wackomenace.co.uk) website to sign in to other services using GitHub as the authentication provider.

## Quick start (local development)

Ensure Ruby 3.3.4 is installed. Then run:

```
cp .env.example .env
bundle install
bundle exec puma
```

Remember to edit your new `.env` file to set the GitHub details and private key for JWTs.

## Authentication providers

Since I originally built Authmenace for myself, I have only implemented GitHub as an authentication provider. However, I am more than happy for others to contribute extra providers that have corresponding Omniauth strategies.

### GitHub

To use the GitHub provider, you need to create a new OAuth app to receive a client ID and secret using the following steps:

1. Go to <https://github.com/settings/developers>
1. Click the "New OAuth App" button
1. Give your application a name and homepage (you should set these to the name and homepage of your website)
1. Set the authorization callback URL to `https://your.domain/auth/github/callback`, where `your.domain` is the domain you're using to host Authmenace
1. Click the "Register application" button
1. You will see a client ID - make a note of this
1. Click the "Generate a new client secret" button
1. Make a note of the client secret (it will not be shown again)
1. Use these details to set the environment variables for the app

## Environment variables

* `GITHUB_CLIENT_ID`: the client ID of the GitHub OAuth app
* `GITHUB_CLIENT_SECRET`: the client secret of the GitHub OAuth app
* `GITHUB_USERNAME`: your GitHub username (only this username will be allowed to authenticate)
* `JWT_PRIVATE_KEY`: an ECDSA private key to use for signing generated JWTs

## Testing

`bundle exec rspec`

## Bug reports

Please open an issue on the GitHub repository for any bugs.

## Contributing

All contributions are welcome. Feel free to fork the original GitHub repository, make your changes and then open a Pull Request against the original GitHub repository. Alternatively, if you're not comfortable writing code, please open an issue.

## Licence

[MIT licence](LICENSE)
