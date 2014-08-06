
THIS_DIR = File.dirname(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__)
$: << File.absolute_path(File.join(THIS_DIR, '..', '..'))

require 'json'
require 'omf/slice_service'
require 'omf/slice_service/server'

opts = OMF::SliceService::DEF_OPTS
OMF::SliceService::Server.new.run(opts)
