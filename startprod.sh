sudo sysctl -w vm.max_map_count=262144
docker-compose -f docker-compose.yml -f docker-compose-search.yml -f docker-compose-prod.yml  stop
docker-compose -f docker-compose.yml -f docker-compose-search.yml -f docker-compose-prod.yml  rm -f
docker-compose -f docker-compose.yml -f docker-compose-search.yml -f docker-compose-prod.yml up
