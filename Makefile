.PHONY: all install clean

all: clean
	chmod +x ./make.sh
	./make.sh

clean:
	rm -f ./docker-maintenance.sh

install:
	mkdir /opt/docker-maintenance
	cp ./docker-maintenance.sh /opt/docker-maintenance/docker-maintenance.sh
	