sudo sysctl -w vm.max_map_count=262144
docker-compose -f dc.yml -f dc-prod.yml stop
docker-compose -f dc.yml -f dc-prod.yml rm -f
docker-compose -f dc.yml -f dc-prod.yml up
