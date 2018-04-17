all: test
.PHONY: all test clean lldb lldb-test ci ci-setup

PONYC ?= $(shell which ponyc)

PKG=crdt

.deps: bundle.json
	stable fetch

bin/test: $(shell find ${PKG} -name *.pony)
	mkdir -p bin
	stable env $(PONYC) --debug -o bin ${PKG}/test

test: bin/test
	$^

clean:
	rm -rf bin

lldb:
	lldb -o run -- $(shell which stable) env $(PONYC) --debug -o /tmp ${PKG}/test

lldb-test: bin/test
	lldb -o run -- bin/test

ci: test

ci-setup:
	stable fetch
