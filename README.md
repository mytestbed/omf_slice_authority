
OMF Slice Authority
===================

This directory contains the implementations of simple OMF Slice Authority which 
allows for the manipulation and observation of slices and their state.

Installation
------------

At this stage the best course of action is to clone the repository

    % git clone https://github.com/mytestbed/omf_sfa.git
    % cd omf_sfa
    % export OMF_SFA_HOME=`pwd`
    % bundle install
    % cd ..
    % git clone https://github.com/mytestbed/omf_slice_authority.git
    
Starting the Service
--------------------

To start a slice authority with a some pre-populated resources ('--test-load-state') from this directory, run the following:

    % cd omf_slice_authority
    % ruby -I lib -I $OMF_SFA_HOME/lib lib/omf/slice_authority.rb --test-load-state  --dm-auto-upgrade --disable-https start
    
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
    
