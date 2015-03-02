
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
    INFO Server: >> Thin web server (v1.3.1 codename Triple Espresso)
    ...
    INFO Server: >> Listening on 0.0.0.0:8006, CTRL+C to stop
    INFO AuthorityClass: Fetching authority list from 'https://flsmonitor.fed4fire.eu/testbeds.xml'
    INFO SFA: Checking Clearinghouse API version at 'https://ch.geni.net/SA'
    ...


REST API
--------

The **Slice Service** is primarily providing coordination across other services, such as the _Federation Services_ [[V2][Fedv2], [V3][Fedv3]] and various _Aggregate Managers_ [[V2][AMv2], [V3][AMv3]]. As many of these service calls requiring substantial time to complete and to stay with the asynchronous nature of
web services, this service is using two mechanisms to indicate state and progress.

If the **Slice Service** is missing necessary information to even get started processing
a request, it will return a 504 (Gateway Timeout) error, indicating that it is safe
to retry the same request in a short time (~ 10sec).

If a request is accepted but will require time to complete, the **Slice Service** will
return a 301 redirect to a promise resource which should ultimately return the
originally requested resource. The Promise resource will return a 504 code while
the associated work is in progress. When the promise is resolved it will either return
the result of the original request with a 200 code, or any respective error code
if the request cannot be fulfilled. Please note, that promises are temporary resources
which may be removed some time after the associated request has completed. However, this
should not be a concern in normal operation where a client is expected to regularly
check the state of the promise.

    $ curl -v -L http://localhost:8006/users/urn:publicid:IDN+ch.geni.net+user+maxott/slice_members
    ...
    < HTTP/1.1 302 Moved Temporarily
    < Location: /promises/22ccd749-9b67-41ee-9de2-afee6ad0457c
    ...
    > GET /promises/22ccd749-9b67-41ee-9de2-afee6ad0457c HTTP/1.1
    ...
    < HTTP/1.1 504 Gateway Time-out
    ...
    {
      "type": "retry",
      "delay": 10,
      "url": "http://localhost:8006/promises/22ccd749-9b67-41ee-9de2-afee6ad0457c",
      "progress": [
        "2014-10-04T05:30:08Z:   slice_members started",
        "2014-10-04T05:30:08Z:     LookupSlicesForMemberTask started"
      ]
    }
    ...
    $ curl -v -L http://localhost:8006/promises/22ccd749-9b67-41ee-9de2-afee6ad0457c
    < HTTP/1.1 200 OK
    ...
    [
      {
        "name": "foo70",
        "href": "http://bleeding.mytestbed.net:8006/slice_members/4e24817c-5248-4509-8122-e49e60bada49",
        ...


The following assumes that service is running locally and listens at port 8006.

### Authentication & Authorisation

As mentioned above, this service is primarily a coordination activity calling on other services to
do the actual work. In the GENI context, any "restricted" call needs to be accompanied by a set of
credentials identifying the identity and privileges of the caller. As this service is calling
_on behalf of someone else_, it needs to include a [_Speaks For_](http://groups.geni.net/geni/raw-attachment/wiki/GEC19Agenda/DeveloperTopics/SpeaksFor-TomMitchell.pdf) credential with each of these calls.
These credentials need to come from the caller of this service.

One option would be to authenticate users to this service and provide a mechanism to store their
_speaksFor_ credentials, another option is to request the caller to associate the appropriate
credentials with each session.

It is the later we have implemented. There is no specific authentication step. We use the normal HTTP
session context for users to upload _speaksFor_ credentials:

    $ curl -X POST --data-binary @john_speaks_for.xml http://localhost:8006/speaks_fors/urn:publicid:IDN+ch.geni.net+user+john -c cookie_jar.txt -b cookie_jar.txt

The "urn:publicid:IDN+ch.geni.net+user+foo" urn tag allows both the for uploading multiple _speaksFor_ credentials to be individually
selected within a specific call through the HTTP header field __X-SpeaksFor__ and the association of a specific credential to a urn

    $ curl ... -H "X-SpeaksFor: urn:publicid:IDN+ch.geni.net+user+john" ...

If only one _speaksFor_ is uploaded it is used by default and therefore doesn't require the __X-SpeaksFor__
header.

Please note, that the uploaded credentials are only valid within a specific session. When the session has
ended or expired, all associated credentials will be deleted.  In order to maintain session state across multiple cURL commands use the -b and -c flags to specify the local cookie store.

A list of the currently active credentials can be obtained through the following call which will
return the list of registered tags.

    $ curl http://localhost:8006/speaks_fors
    [ "urn:publicid:IDN+ch.geni.net+user+john" ]

The tag "__default__" is used if only one _speaksFor_ is uploaded and no tag name was provided.


### User

If you started the service with the '--test-load-state' option, the service got preloaded with a few
resources. To list all users:

    $ curl http://localhost:8006/users
    [
      {
        "name": "urn:publicid:IDN+ch.geni.net+user+maxott",
        "href": "http://localhost:8006/users/22ccd749-9b67-41ee-9de2-afee6ad0457c",
      },
      {
         ...
    ]

To find out more about a particular user:

    $ curl http://localhost:8006/users/urn:publicid:IDN+ch.geni.net+user+maxott
    {
      "urn": "urn:publicid:IDN+ch.geni.net+user+maxott",
      "uuid": "22ccd749-9b67-41ee-9de2-afee6ad0457c",
      "href": "http://localhost:8006/users/22ccd749-9b67-41ee-9de2-afee6ad0457c",
      "type": "user",
      "created_at": "2014-09-28T20:45:26+10:00",
      "speaks_for": "http://localhost:8006/speaks_fors/22ccd749-9b67-41ee-9de2-afee6ad0457c",
      "slice_memberships": "http://localhost:8006/users/22ccd749-9b67-41ee-9de2-afee6ad0457c/slice_memberships"
      "slices_checked_at": "2014-10-04T15:42:14+10:00",
      "ssh_keys": "http://localhost:8006/users/22ccd749-9b67-41ee-9de2-afee6ad0457c/ssh_keys",
      "ssh_keys_checked_at": "2014-10-04T15:42:14+10:00"
    }

To create a new user:

    $ curl -X POST -H "Content-Type: application/json" \
         -d '{"urn":"urn:publicid:IDN+ch.geni.net+user+johnsmith"}' \
         http://localhost:8006/users
    {
      "urn": "urn:publicid:IDN+ch.geni.net+user+johnsmith",
      "uuid": "8f2f5110-c0b4-4e31-baf9-615f5bc75a43",
      "href": "http://localhost:8006/users/8f2f5110-c0b4-4e31-baf9-615f5bc75a43",
      "type": "user",
      "created_at": "2014-09-28T20:48:17+10:00",
    }

To add a speaks-for credential to a user, POST it to '/speaks_fors/user_uuid'

    $ curl -X POST --data-binary @john_speaks_for.xml http://localhost:8006/speaks_fors/urn:publicid:IDN+ch.geni.net+user+johnsmith

*Use --data-binary option to make sure the white space inside the speaks-for are intact.*

Please note that both the record's 'urn' as well as its 'uuid' can be used in all calls targeting a specific
resource.


### Slices

To get a listing of all the active slices a user is a member of:

    % curl http://localhost:8006/users/urn:publicid:IDN+ch.geni.net+user+johnsmith/slice_memberships
    [
      {
        "slice_urn": "urn:publicid:IDN+ch.geni.net:max_mystery_project+slice+foo51",
        "role": "LEAD",
        "href": "http://localhost:8006/users/8f2f5110-c0b4-4e31-baf9-615f5bc75a43/slice_memberships/4e24817c-5248-4509-8122-e49e60bada49",
      },
      ...

Please be prepared to receive a '504' HTTP response, as discussed above, requesting you to try again
in a few seconds.


......

    bin/request_slice -v -p bin/create_slice -s urn:publicid:IDN+ch.geni.net:max_mystery_project+slice+foo71 -u urn:publicid:IDN+ch.geni.net+user+maxott -p urn:publicid:IDN+ch.geni.net+project+mystery_project -u urn:publicid:IDN+ch.geni.net+user+maxott --url http://localhost:8006 -s foo80 test/one_node_openvz.xml

    bin/create_slivers -s urn:publicid:IDN+ch.geni.net:max_mystery_project+slice+foo71 \
         -u urn:publicid:IDN+ch.geni.net+user+maxott \
         --url http://localhost:8006 \
         test/one_node_openvz.xml

### Authorities

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

Just point your browser at [http://localhost:8006](/)

Debugging Hints
---------------

Verifying that public and private key belong together [[ref][0]]

    Certificate: openssl x509 -noout -modulus -in server.crt | openssl md5
    Private Key: openssl rsa -noout -modulus -in server.key | openssl md5
    CSR: openssl req -noout -modulus -in server.csr | openssl md5


[0]: http://stackoverflow.com/a/280912/3528225 "StackOverflow: How do you test a public/private keypair?"

[Fedv2]:  http://groups.geni.net/geni/wiki/CommonFederationAPIv2 "Federation Service API"

[Fedv3]: https://fed4fire-testbeds.ilabt.iminds.be/asciidoc/federation-am-api.html "Federation AM API"

[AMv2]: http://groups.geni.net/geni/wiki/GAPI_AM_API_V2 "GENI Aggregate Manager API Version 2"

[AMv3]: http://groups.geni.net/geni/wiki/GAPI_AM_API_V3 "GENI Aggregate Manager API Version 3"
