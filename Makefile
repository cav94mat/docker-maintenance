.PHONY: image clean install compile install-sys clean-sys configure

IMAGE=cav94mat/docker-maintenance
SIDELOAD=docker-sideload.tar

image: clean
	IMAGE='$(IMAGE)' DOCKER_SIDELOAD="$(SIDELOAD)" ./make.sh image

clean: configure
	rm -f './${SIDELOAD}' './test/${SIDELOAD}'
	( cd ./test; docker-compose down )
	docker rmi '${IMAGE}' || true

test: image
	mv './${SIDELOAD}' './test/${SIDELOAD}'
	IMAGE='$(IMAGE)' ./make.sh test

compile: clean-sys
	IMAGE='$(IMAGE)' ./make.sh compile

install-sys: compile
	./make.sh install

clean-sys: configure
	./make.sh clean

configure:
	chmod +x ./make.sh ./scripts/*