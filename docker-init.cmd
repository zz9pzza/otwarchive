copy config\database.docker.yml config\database.yml
copy config\redis.docker.yml config\redis.yml
copy config\local.docker.yml config\local.yml

docker-compose up -d

timeout 60

docker-compose run -e RAILS_ENV=development web script/reset_database.sh
docker-compose run -e RAILS_ENV=test web script/reset_database.sh
