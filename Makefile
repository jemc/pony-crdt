all: test
.PHONY: all test clean lldb lldb-test ci ci-setup

PKG=crdt

bin/test: $(shell find ${PKG} -name *.pony)
	mkdir -p bin
	ponyc --debug -o bin ${PKG}/test

test: bin/test
	$^

clean:
	rm -rf bin

lldb:
	lldb -o run -- $(shell which ponyc) --debug -o /tmp ${PKG}/test

lldb-test: bin/test
	lldb -o run -- bin/test

ci: test

ci-setup:
