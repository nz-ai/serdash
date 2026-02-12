FROM ruby:3.3-slim

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libpq-dev nmap iputils-ping && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock* ./
RUN bundle install

COPY . .

EXPOSE 3001

CMD ["bundle", "exec", "puma", "-p", "3001"]
