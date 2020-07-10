FROM ruby:2.6.5
RUN apt-get update && apt-get install -y default-mysql-client calibre

WORKDIR /otwa

COPY Gemfile .
COPY Gemfile.lock .


RUN gem install bundler -v 1.17.3 && bundle install

RUN rm -rf /otwa
RUN mkdir  -p /otwa

EXPOSE 3000
CMD bundle exec rails s -p 3000