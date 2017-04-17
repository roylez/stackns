# Stackns

A small DNS server for OpenStack client environment that makes instances' names resolvable.

## Installation

### Compile from source

**To compile, you would need to have Elixir 1.3 or newer installed.**

This compiles the code

    make build

To run the application directly

    ./_build/prod/rel/$(NAME)/bin/stackns start

### Build a Debian / Ubuntu package

    sudo apt-get install ruby ruby-dev rubygems build-essential
    gem install fpm
    make

## Configuration

The configuration file for stackns is `/etc/stackns.yml`.


    dns_address: 8.8.8.8
    dns_port:    53

    listening_port: 53

    rabbit_exchange: neutron
    rabbit_topic:    notifications.info

    # rabbitmq auth section
    rabbit_host:     changeme
    rabbit_vhost:    changeme
    rabbit_user:     changeme
    rabbit_passwd:   changeme

    # openstack auth section
    os_user:         changeme
    os_passwd:       changeme
    os_tenant:       changeme
    os_auth_url:     changeme   # something like http://10.230.20.50:5000/v2.0
