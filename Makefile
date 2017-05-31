.PHONY: all test
all: test

test: test/test
	test/test

clean:
	rm -f test/test

test/test: $(shell find crdt/*.pony) $(shell find test/*.pony)
	ponyc --debug -o test test
