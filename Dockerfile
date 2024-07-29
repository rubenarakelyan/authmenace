FROM ruby:3.3.4 AS base
WORKDIR /app

COPY Gemfile Gemfile.lock ./

FROM base AS prod-deps
RUN bundle install --without development
COPY . .

EXPOSE 9292
CMD ["bundle", "exec", "puma"]
