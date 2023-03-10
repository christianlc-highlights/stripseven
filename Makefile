
export NAME := $(shell pwd | xargs basename)
export TS := $(shell date +%s)
export sha := $(shell git rev-parse --short HEAD)

.DEFAULT_GOAL := @goal
.ONESHELL:

## recipe
@goal: distclean dist build check

dist: export portecho ?= 1221
dist: export test := *
dist:
	mkdir -p $@ $@/manifest
	go mod init github.com/christianlc-highlights/stripseven ||:
	go mod tidy

	# add tests to dist
	cp -rf test $@
	cp sh/entrypoint.sh $@/test

	# interpolate manifest
	cat manifest/* \
		| envsubst \
		| tee $@/manifest.yaml

	# add bats struts
	# https://bats-core.readthedocs.io/en/stable/tutorial.html#quick-installation
	mkdir -p $@/test/test_helper
	git clone https://github.com/bats-core/bats-core.git $@/test/bats
	git clone https://github.com/bats-core/bats-support.git $@/test/test_helper/bats-support
	git clone https://github.com/bats-core/bats-assert.git $@/test/test_helper/bats-assert

build: dist
	docker build \
		-t local/stripseven \
		-t docker.io/christianelsee/stripseven \
		-t docker.io/christianelsee/stripseven:$(sha) \
		.

check: build
	cp -f test/build.bats dist/test/
	dist/test/bats/bin/bats --tap dist/test/build.bats

namespace:
	kubectl create namespace $(NAME) --dry-run=client -oyaml \
		| kubectl apply -f-
	kubectl config set-context \
		--current \
		--namespace $(NAME)

install: namespace build
	<./docker.io.token.gpg gpg -d \
		| xargs -- \
			docker login -u christianelsee -p
	docker push docker.io/christianelsee/stripseven:$(sha)


	kubectl delete configmap test ||:
	kubectl create configmap test \
		--from-file=dist/test
	kubectl apply -f dist/manifest.yaml --dry-run=server
	kubectl apply -f dist/manifest.yaml

	kubectl rollout status deployment
	kubectl get all -lapp.kubernetes.io/part-of=$(NAME)

check-install: install
	export ingress=$$(
		kubectl get ingress stripseven -ojson \
			| jq -re .status.loadBalancer.ingress[0].ip
	)
	dist/test/bats/bin/bats --tap dist/test/install.bats

distclean:
	rm -rvf dist

clean: namespace
	kubectl delete -f dist/manifest.yaml ||:

lint:
	goimports -l .
	golint ./...
	go vet ./... ||:
