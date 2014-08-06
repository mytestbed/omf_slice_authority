
OMF Slice Service
=================

This directory contains the implementations of simple OMF Slice Authority which
allows for the manipulation and observation of slices and their state.

Installation
------------

At this stage the best course of action is to clone the repository

    git clone https://github.com/mytestbed/omf_slice_service.git
    cd omf_slice_service

This service requires 'ruby1.9.3'. If you don't have one in this account, install it through rvm:

    curl -sSL https://get.rvm.io | bash -s stable --ruby=1.9.3

Before installing the necessary Gems, make sure that you have the necessary libraries installed. On a Ubuntu
system, execute the following:

    sudo apt-get install sqlite3
    sudo apt-get install libxml2-dev
    sudo apt-get install libxslt-dev

On Ubuntu 12.04 LTS you will also need to install the following package:

    sudo apt-get install libsqlite3-dev

Now we are ready to install all the necessary Gems

    bundle install --path vendor
    rake post-install


Starting the Service
--------------------

To start a job service from this directory, run the following:

    cd omf_slice_service
    rake run

which should result in something like:

    INFO Server: Slice Service V xx
    DEBUG Server: Options: {...}
    INFO Server: >> Thin web server (v1.3.1 codename Triple Espresso)
    DEBUG Server: >> Debugging ON
    DEBUG Server: >> Tracing ON
    INFO Server: >> Maximum connections set to 1024
    INFO Server: >> Listening on 0.0.0.0:8006, CTRL+C to stop
    INFO AuthorityClass: Fetching authority list from 'https://flsmonitor.fed4fire.eu/testbeds.xml'
    INFO SFA: Checking Clearinghouse API version at 'https://ch.geni.net/SA'
    ...


Testing REST API
----------------

If you started the service with the '--test-load-state' option, the service got preloaded with a few
resources. To list all users:

    $ curl http://localhost:8006/users
    [
      {
        "uuid": "22ccd749-9b67-41ee-9de2-afee6ad0457c",
        "href": "http://localhost:8006/users/22ccd749-9b67-41ee-9de2-afee6ad0457c",
        "name": "max",
        "type": "user"
      }
    ]

To get a listing of all the know authorities, run the following:

    curl http://localhost:8006/authorities
    [
      {
        "uuid": "51d4aead-ef19-4664-94a9-c632c5498cca",
        "href": "http://localhost:8006/authorities/51d4aead-ef19-4664-94a9-c632c5498cca",
        "name": "iMinds Virtual Wall 1",
        "type": "authority",
        "role": "slice authority"
      },
      {
        "uuid": "b9141b8c-f16e-4d9a-a233-005f3fff5af4",
        "href": "http://localhost:8006/authorities/b9141b8c-f16e-4d9a-a233-005f3fff5af4",
        "name": "iMinds WiLab 2",
        "type": "authority",
        "role": "slice authority"
      },
      ...

Exploring the Service with a Web Browser
----------------------------------------

Just point your browser at (http://localhost:8006/)

Debugging Hints
---------------

Verifying that public and private key belong together (http://stackoverflow.com/a/280912/3528225)

    Certificate: openssl x509 -noout -modulus -in server.crt | openssl md5
    Private Key: openssl rsa -noout -modulus -in server.key | openssl md5
    CSR: openssl req -noout -modulus -in server.csr | openssl md5

