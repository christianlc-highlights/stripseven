
.DEFAULT_GOAL := @goal
.ONESHELL:

## recipe
@goal: cleandist dist build check

dist:
	mkdir $@
	go install github.com/spf13/cobra-cli@v1.3.0
	- go mod init github.com/christianlc-highlights/stripseven

	# add bats struts
	# https://bats-core.readthedocs.io/en/stable/tutorial.html#quick-installation
	mkdir -p $@/test/test_helper
	git clone https://github.com/bats-core/bats-core.git $@/test/bats
	git clone https://github.com/bats-core/bats-support.git $@/test/test_helper/bats-support
	git clone https://github.com/bats-core/bats-assert.git $@/test/test_helper/bats-assert

run:
	go run main.go

build: dist
	go build -o dist/build main.go

check: dist build
	# start an echo server
	socat -T1 tcp-l:2000,reuseaddr,fork system:"echo; cat" &>/dev/null &

	rsync -av bats/ dist/test
	dist/test/bats/bin/bats --tap dist/test ||:

	# kill the echo server
	kill $$!

fubar:
	v=asdf
	echo $$v

lint:
	goimports -l -w .
	golint ./...
	go vet ./... ||:

cleandist:
	rm -rvf dist
