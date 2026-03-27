# Exheres build testing with Exherbo Docker images

image_name := "exheres-test"

build:
    docker build -f Dockerfile.test -t {{image_name}} .

test-build package: build
    docker run --rm -t --network=host {{image_name}} \
        bash -c 'cave resolve -x {{package}} 2>&1'

test-shell package="": build
    @if [ -n "{{package}}" ]; then \
        docker run -it --rm --network=host {{image_name}} \
            bash -c 'cave resolve -x {{package}} 2>&1; exec bash'; \
    else \
        docker run -it --rm --network=host {{image_name}} bash; \
    fi

clean:
    docker rmi {{image_name}} 2>/dev/null || true
