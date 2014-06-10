
OMF Slice Authority
===================

This directory contains the implementations of simple OMF Slice Authority which
allows for the manipulation and observation of slices and their state.

Installation
------------

At this stage the best course of action is to clone the repository

    git clone https://github.com/mytestbed/omf_slice_authority.git
    cd omf_job_service

This service requires 'ruby1.9.3' provided by RVM. If you don't have one in this account, install it with:

    curl -sSL https://get.rvm.io | bash -s stable --ruby=1.9.3

Before installing the necessary Gems, make sure that you have the necessary libraries installed. On a Ubuntu
system, execute the following:

    sudo apt-get install sqlite3
    sudo apt-get install libxml2-dev
    sudo apt-get install libxslt-dev

On Ubuntu 12.04 LTS you will also need to install the following package:

    sudo apt-get install libsqlite3-dev

** At this stage, please clone https://github.com/mytestbed/omf_sfa.git into the parent directory and update it (git pull) regularily. **

Now we are ready to install all the necessary Gems

    bundle install --path vendor
    rake post-install

Before starting the service, please also install tan OMF EC in the 'omf_ec' directoy
following the instructions in the [README](omf_ec/README.md) in that directory.

Starting the Service
--------------------

To start a job service from this directory, run the following:

    cd omf_slice_authority
    rake run

which should result in something like:

    DEBUG Server: options: {:app_name=>"exp_server", :chdir=>"/Users/max/src/gimi_experiment_service", :environment=>"development", :address=>"0.0.0.0", :port=>8002, :timeout=>30, :log=>"/tmp/exp_server_thin.log", :pid=>"/tmp/exp_server.pid", :max_conns=>1024, :max_persistent_conns=>512, :require=>[], :wait=>30, :rackup=>"/Users/max/src/gimi_experiment_service/lib/gimi/exp_service/config.ru", :static_dirs=>["./resources", "/Users/max/src/omf_sfa/lib/omf_common/thin/../../../share/htdocs"], :static_dirs_pre=>["./resources", "/Users/max/src/omf_sfa/lib/omf_common/thin/../../../share/htdocs"], :handlers=>{:pre_rackup=>#<Proc:0x007ffd0ab91388@/Users/max/src/gimi_experiment_service/lib/gimi/exp_service/server.rb:83 (lambda)>, :pre_parse=>#<Proc:0x007ffd0ab91360@/Users/max/src/gimi_experiment_service/lib/gimi/exp_service/server.rb:85 (lambda)>, :pre_run=>#<Proc:0x007ffd0ab91338@/Users/max/src/gimi_experiment_service/lib/gimi/exp_service/server.rb:94 (lambda)>}, :dm_db=>"sqlite:///tmp/gimi_test.db", :dm_log=>"/tmp/gimi_exp_server-dm.log", :load_test_state=>true, :dm_auto_upgrade=>true}
    INFO Server: >> Thin web server (v1.3.1 codename Triple Espresso)
    DEBUG Server: >> Debugging ON
    DEBUG Server: >> Tracing ON
    INFO Server: >> Maximum connections set to 1024
    INFO Server: >> Listening on 0.0.0.0:8006, CTRL+C to stop


Testing REST API
----------------

If you started the service with the '--test-load-state' option, the service got preloaded with a few
resources. To list all slices:

    $ curl http://localhost:8006/slices
    {
    }

