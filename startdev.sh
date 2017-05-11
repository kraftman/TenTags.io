sudo sysctl -w vm.max_map_count=262144
docker-compose -f dc.yml -f dc-dev.yml -f dc-search.yml stop
docker-compose -f dc.yml -f dc-dev.yml -f dc-search.yml rm -f
docker-compose -f dc.yml -f dc-dev.yml -f dc-search.yml up
