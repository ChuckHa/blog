HUGO = hugo
GIT = git

.PHONY: build publish clean rebuild

build:
	$(HUGO)

publish:
	$(MAKE) -C public
	$(GIT) add public
	$(GIT) commit -s -m 'Update submodule'
	$(GIT) push

clean:
	find public -not -path "*/.git*" -not -path "*/Makefile" -delete

rebuild: clean build
