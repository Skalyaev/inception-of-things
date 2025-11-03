USERNAME=anguinau
VOLUME_DIR=volume

all: up

up:
	mkdir -p ${VOLUME_DIR}
	vagrant up

ssh:
	vagrant ssh ${USERNAME}S

down:
	vagrant halt

clean:
	vagrant destroy -f

re: clean up

.PHONY: all up ssh down clean re
