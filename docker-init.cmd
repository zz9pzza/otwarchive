copy config\database.docker.yml config\database.yml
copy config\redis.docker.yml config\redis.yml
copy config\local.docker.yml config\local.yml

docker-compose up -d

timeout 60

docker-compose run web rake db:create
docker-compose run web rake db:schema:load
docker-compose run web rake db:migrate
docker-compose run web rake db:otwseed

docker-compose run web rake work:missing_stat_counters
docker-compose run web rake skins:load_site_skins

docker-compose run web rake search:index_tags
docker-compose run web rake search:index_works
docker-compose run web rake search:index_pseuds
docker-compose run web rake search:index_bookmarks