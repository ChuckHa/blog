HUGO = hugo
GIT = git

.PHONY: build publish clean rebuild

build:
	$(HUGO)

publish:
	$(MAKE) -C public

clean:
	find public -not -path "*/.git*" -delete

rebuild: clean build
