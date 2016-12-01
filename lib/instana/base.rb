require "instana/version"
require 'instana/logger'
require "instana/util"

module Instana
  class << self
    attr_accessor :agent
    attr_accessor :collectors
    attr_accessor :tracer
    attr_accessor :processor
    attr_accessor :config
    attr_accessor :logger
    attr_accessor :pid

    ##
    # setup
    #
    # Setup the Instana language agent to an informal "ready
    # to run" state.
    #
    def setup
      @logger = ::Instana::XLogger.new(STDOUT)
      if ENV.key?('INSTANA_GEM_TEST') || ENV.key?('INSTANA_GEM_DEV')
        @logger.level = Logger::DEBUG
      else
        @logger.level = Logger::WARN
      end
      @logger.unknown "Stan is on the scene.  Starting Instana instrumentation."

      @agent  = ::Instana::Agent.new
      @tracer = ::Instana::Tracer.new
      @processor = ::Instana::Processor.new
      @collectors = []

      # Store the current pid so we can detect a potential fork
      # later on
      @pid = ::Process.pid
    end

    def pid_change?
      @pid != ::Process.pid
    end
  end
end