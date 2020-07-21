.PHONY: image clean install compile install-sys clean-sys configure

IMAGE=cav94mat/docker-maintenance
SIDELOAD=docker-sideload.tar
BUILD='0.9a'

image: clean
	docker build -t ${IMAGE} .
	docker save -o './${SIDELOAD}' ${IMAGE}

clean: configure
	rm -f './${SIDELOAD}' './test/${SIDELOAD}'
	( cd ./test; docker-compose down )
	docker rmi '${IMAGE}' || true

test: image
	mv './${SIDELOAD}' './test/${SIDELOAD}'
	IMAGE='$(IMAGE)' ./make.sh test

compile: clean-sys
	BUILD='$(BUILD)' IMAGE='$(IMAGE)' ./make.sh compile

install-sys: compile
	./make.sh install

clean-sys: configure
	./make.sh clean

configure:
	chmod +x ./make.sh