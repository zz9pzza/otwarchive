#!/bin/bash

set -ex

cp -f config/database.docker.yml config/database.yml
cp -f config/redis.docker.yml config/redis.yml
cp -f config/local.docker.yml config/local.yml

docker-compose build

docker-compose run -e RAILS_ENV=development web script/reset_database.sh
docker-compose run -e RAILS_ENV=test web script/reset_database.sh
