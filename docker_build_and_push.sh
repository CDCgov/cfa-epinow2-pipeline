TAG=$1
IMAGE=ghcr.io/cdcgov/cfa-epinow2-pipeline
BUILDER=docker-container-driver-builder

# create a builder. By default will use docker-container driver which allows cache export
docker buildx create --name "$BUILDER" || true

docker pull "$IMAGE:cache"
echo "Pulled image - '$IMAGE:cache'"

# use the cache tag and the latest tag for cache sources
# in practice, the cache tag would instead be the name of a branch when adding
# commits to an open PR
time docker buildx build --push -t "$IMAGE" \
	--builder "$BUILDER" \
	--cache-from "type=registry,ref=$IMAGE:$TAG" \
	--cache-from "type=registry,ref=$IMAGE:cache" \
	--cache-from "type=registry,ref=$IMAGE:latest" \
	--cache-to "type=registry,ref=$IMAGE:$TAG,mode=max" \
	-f Dockerfile.unified .
