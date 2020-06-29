.PHONY: all install clean

all: clean
	chmod +x ./make.sh
	./make.sh

clean:
	rm -f ./docker-maintenance.sh **/.last-maintenance.log

install: all
	mkdir -p /opt/docker-maintenance
	cp ./docker-maintenance.sh /opt/docker-maintenance/docker-maintenance.sh
	cp -RT ./scripts /opt/docker-maintenance/scripts
	ln -fs /opt/docker-maintenance/docker-maintenance.sh /usr/bin/docker-maintenance

docker: all
	docker build -t cav94mat/docker-maintenance .

docker-run: docker
	docker-compose up -d
