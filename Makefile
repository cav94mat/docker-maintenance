.PHONY: image clean install compile install-sys clean-sys configure test

IMAGE=cav94mat/docker-maintenance
OUTPUT=./docker-maintenance.sh
SIDELOAD=docker-sideload.tar

$(SIDELOAD): clean
	IMAGE='$(IMAGE)' DOCKER_SIDELOAD="$(SIDELOAD)" ./make.sh image

image: $(SIDELOAD)
	
clean: configure
	rm -f './${SIDELOAD}' './test/${SIDELOAD}'
	( cd ./test; docker-compose down )
	docker rmi '${IMAGE}' || true

test: $(SIDELOAD)
	cp './${SIDELOAD}' './test/${SIDELOAD}'
	IMAGE='$(IMAGE)' ./make.sh test

$(OUTPUT): clean-sys 
	IMAGE='$(IMAGE)' OUTPUT="$(OUTPUT)" ./make.sh compile

compile: $(OUTPUT)

install-sys: $(OUTPUT)
	./make.sh install

clean-sys: configure
	./make.sh clean

configure:
	chmod +x ./make.sh ./scripts/*