
export BUILDKIT_PROGRESS=plain

container ?= cwedgwood/ulogd2:latest

default: container-tag

%.tar.bz2: %.tar
	pbzip2 -9f $^

opt-netfilter.tar: .iid
	docker run --rm $$(cat .iid) tar -c /opt/netfilter/ > $@

# this will block, kill it when satisfied it's doing something useful
container-test: .iid
	-docker kill ulogd2-test
	mkdir -p logs-flows
	rm -f logs-flows/fifo
	mkfifo logs-flows/fifo
	docker run \
		--name=ulogd2-test \
		-v $(PWD)/logs-flows/:/var/log/flows/:rw \
		-v $(PWD)/test-ulogd.conf:/opt/netfilter/etc/ulogd.conf:ro \
		--privileged=true --net=host -e TERM=dumb --rm -it $$(cat .iid) /opt/netfilter/sbin/ulogd --verbose

.iid: Makefile Dockerfile
	docker build --iidfile=$@ .

container-release: container-tag
	bash -c "( set -o pipefail ; docker push $(container) | cat )"

container-tag: Makefile .iid
	docker tag $$(cat .iid) $(container)

clean:
	-docker kill ulogd2-test
	rm -f *~ .iid opt-netfilter.tar.bz2
	sudo rm -rf logs-flows
