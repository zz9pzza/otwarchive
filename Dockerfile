FROM ruby:2.6.5
RUN apt-get update && apt-get install -y default-mysql-client

WORKDIR /otwa

RUN git clone https://github.com/zz9pzza/otwarchive.git .
RUN git checkout docker-compose-james
RUN cp -n config/database.docker.yml config/database.yml
RUN cp -n config/redis.docker.yml config/redis.yml
RUN cp -n config/local.docker.yml config/local.yml


RUN gem install bundler -v 1.17.3 && bundle install

RUN rm -rf /otwa
RUN mkdir  -p /otwa

EXPOSE 3000
CMD bundle exec rails s -p 3000