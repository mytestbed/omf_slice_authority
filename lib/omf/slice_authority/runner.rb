
THIS_DIR = File.dirname(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__)
$: << File.absolute_path(File.join(THIS_DIR, '..', '..'))

require 'json'
require 'omf/slice_authority'
require 'omf/slice_authority/server'

opts = OMF::SliceAuthority::DEF_OPTS
OMF::SliceAuthority::Server.new.run(opts)
