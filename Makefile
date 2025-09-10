DOCKER_USER = aygp-dr
IMAGE_NAME = freebsd
VERSION ?= 14.0-RELEASE
IMAGE = $(DOCKER_USER)/$(IMAGE_NAME):$(VERSION)

.PHONY: build run push clean

build:
	docker build --build-arg FREEBSD_VERSION=$(VERSION) -t $(IMAGE) .

run:
	docker run -it --rm --privileged -p 2222:22 $(IMAGE)

push: build
	docker push $(IMAGE)

clean:
	docker rmi -f $(IMAGE) || true
