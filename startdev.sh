sudo sysctl -w vm.max_map_count=262144
docker-compose -f docker-compose.yml -f docker-compose-search.yml rm -f
docker-compose -f docker-compose.yml -f docker-compose-search.yml up
