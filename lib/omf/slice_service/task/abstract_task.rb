
require 'omf_base/lobject'

module OMF::SliceService::Task

  class AbstractTask < OMF::Base::LObject
    # return true if speaks-for is provided
    def speaks_for?
      Thread.current[:speaks_for] != nil
    end
  end
end