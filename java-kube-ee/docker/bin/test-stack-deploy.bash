#!/usr/bin/env bash

bash ./gradlew clean build

docker swarm init
docker service create --detach=false --name registry --publish 5000:5000 registry:2
docker-compose -f ./docker/src/stack-deploy.yml build --force-rm --no-cache --pull
docker-compose -f ./docker/src/stack-deploy.yml push

stack_name="java-kube-ee"
docker stack deploy --compose-file ./docker/src/stack-deploy.yml "$stack_name"

# put apps in right order
for name in app; do
  service_name="${stack_name}_${name}"

  # info
  echo "waiting for $service_name bootstrap..."
  echo $(docker stack services --filter name="$service_name" --format="{{.Name}} {{.Replicas}}" "$stack_name")
  state=$(docker stack services --filter name="$service_name" --format="{{.Replicas}}" "$stack_name")

  echo "scale up in right order"
  while [ "$state" != "1/1" ]; do
    docker stack services "$stack_name"
    docker service scale --detach=false "$service_name=1"
    state=$(docker stack services --filter name="$service_name" --format="{{.Replicas}}" "$stack_name")
    sleep 1
  done
done

docker stack services "$stack_name"
sleep 30

http :8080

bash ./docker/bin/cleanup.bash
