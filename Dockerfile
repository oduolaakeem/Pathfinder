FROM ruby:4.0.7-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN gem install rails -v 8.1.4

COPY backend/Gemfile backend/Gemfile.lock /app/backend/

RUN bundle install --gemfile /app/backend/Gemfile

CMD ["ruby", "--version"]
