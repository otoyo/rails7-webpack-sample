FROM node:17.3-slim AS node
FROM node:17.3-slim AS build-node-modules

WORKDIR /app

COPY package.json /app/
COPY yarn.lock /app/

RUN yarn install


FROM ruby:3.0.3-slim AS ruby-base

WORKDIR /app

ENV BUNDLE_APP_CONFIG .bundle
ENV BUNDLE_PATH vendor/bundle

# For nokogiri
# https://nokogiri.org/tutorials/installing_nokogiri.html#installing-using-standard-system-libraries
# For mysql
# https://github.com/brianmario/mysql2#linux-and-other-unixes
RUN apt-get update -y && apt-get install -y \
    build-essential \
    vim \
    pkg-config libxml2-dev libxslt-dev \
    libmariadb-dev default-mysql-client


FROM ruby-base AS build-ruby-gems

COPY Gemfile* /app/

RUN bundle config build.nokogiri --use-system-libraries \
 && bundle install -j4


FROM ruby-base

WORKDIR /app

ARG RAILS_ENV
ARG RAILS_MASTER_KEY
ARG DB_USER
ARG DB_PASSWORD
ARG DB_HOST
ARG DB_PORT

RUN apt-get install -y \
    curl \
    gnupg2 \
 && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
 && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg  add - \
 && apt-get update -y && apt-get install -y \
    tzdata \
    google-cloud-sdk \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY --from=node /usr/local/bin/node /usr/local/bin/
COPY --from=node /opt/yarn* /opt/yarn/
RUN ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn \
 && ln -s /opt/yarn/bin/yarnpkg /usr/local/bin/yarnpkg

COPY --from=build-node-modules /app/node_modules node_modules/
COPY --from=build-ruby-gems /app/.bundle .bundle/
COPY --from=build-ruby-gems /app/vendor vendor/

VOLUME /app/node_modules /app/.bundle /app/vendor

COPY . /app

CMD bin/rails server -b 0.0.0.0 -p ${PORT}
