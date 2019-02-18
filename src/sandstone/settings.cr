require "logger"
module Sandstone::ORM
  class Settings
    property database_url : String? = nil
    property logger : Logger
    def initialize
      @logger = Logger.new nil
      # @logger = Logger.new STDOUT
      @logger.progname = "Sandstone"
    end
  end

  def self.settings
    @@settings ||= Settings.new
  end
end
