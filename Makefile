NAME=stackns
VERSION=0.1.0

.PHONY: build 
.PHONY: package

all: clean build package

clean:
	rm -f *.deb

build:
	# mix local.hex --force
	# mix local.rebar --force
	mix deps.get
	mix deps.compile
	MIX_ENV=prod mix release --env=prod
	rm _build/prod/rel/$(NAME)/releases/$(VERSION)-*/*.tar.gz

package:
	fpm -s dir -t deb -n $(NAME) -v $(VERSION) \
	    --config-files /etc/stackns.yml \
	    --description "A small DNS for openstack client environment" \
	    _build/prod/rel/$(NAME)=/usr/share \
	    debian/stackns.yml=/etc/ \
	    debian/stackns.service=/lib/systemd/system/
