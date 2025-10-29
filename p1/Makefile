USERNAME=anguinau
VOLUME_DIR=volume

all: up

up:
	mkdir -p ${VOLUME_DIR}
	vagrant up

ssh-server:
	vagrant ssh ${USERNAME}S

ssh-worker:
	vagrant ssh ${USERNAME}SW

down:
	vagrant halt

clean:
	vagrant destroy -f
	rm -rf ${VOLUME_DIR}/*

re: clean up

.PHONY: all up ssh-server ssh-worker down clean re
