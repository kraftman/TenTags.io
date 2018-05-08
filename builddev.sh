
docker-compose -f dc.yml -f dc-dev.yml -f dc-search.yml build redis-general

docker-compose -f dc.yml -f dc-dev.yml -f dc-search.yml up redis-general
