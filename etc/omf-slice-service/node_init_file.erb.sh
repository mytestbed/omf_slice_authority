#!/bin/bash

FRCP='amqp://srv.mytestbed.net'
TOP_DIR=/tmp/slice_service
UPDATE_URL='http://<%= Thread.current[:http_host] %>/slices/<%= slice.uuid %>/resource_progress/<%= node_name %>'

rm -rf $TOP_DIR
mkdir -p $TOP_DIR
cd $TOP_DIR

cat > $TOP_DIR/node.json <<XXXXXXXXXXXXXXX
<%=
    JSON.pretty_generate resources[node_name]
%>
XXXXXXXXXXXXXXX

cat > $TOP_DIR/slice.json <<XXXXXXXXXXXXXXX
<%=
  JSON.pretty_generate resources
%>
XXXXXXXXXXXXXXX


if ! type "chef-solo" > /dev/null; then
  echo 'Need to install Chef'
  wget https://www.opscode.com/chef/install.sh -O getchef.sh && bash getchef.sh && rm getchef.sh
fi

COOKBOOK_DIR=$TOP_DIR/cookbooks
mkdir $COOKBOOK_DIR

install_cookbook(){
  name=$1
  url=$2

  cd $COOKBOOK_DIR
  tgz_file=${name}.tgz
  wget $url --no-check-certificate -O $tgz_file
  tar xzf $tgz_file
}

install_cookbook 'chef-repo-master' 'https://github.com/jackhong/chef-repo/archive/master.tar.gz'
cd ${COOKBOOK_DIR}/chef-repo-master && FRCP=$FRCP chef-solo --no-fork -c solo/solo.rb -j solo/solo.json