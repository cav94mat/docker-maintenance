.PHONY: image clean install install-wrapper compile install-sys clean-sys configure

IMAGE='cav94mat/docker-maintenance'

image: clean
	docker build -t ${IMAGE} .
	docker save -o './docker-sideload.tar' ${IMAGE}

clean: configure
	rm -f ./docker-sideload.tar
	docker rmi ${IMAGE} || true

compile: clean-sys
	./make.sh compile

install-sys: compile
	./make.sh install

clean-sys: configure
	./make.sh clean

configure:
	chmod +x ./make.sh