#!/bin/bash

set -ex

# Change directory to root of the repo
cd "$(dirname "$0")/../.."

docker-compose up -d

sleep 3
docker exec -e RAILS_ENV=development -it otwarchive_web_1 bundle exec rails s -p 3000 -b 0.0.0.0

