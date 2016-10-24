require 'net/http'
require 'uri'
require 'json'
require 'sys/proctable'
include Sys

module Instana
  class Agent
    attr_accessor :payload
    attr_accessor :last_snapshot

    def initialize
      @request_timeout = 5000
      @host = '127.0.0.1'
      @port = 42699
      @server_header = 'Instana Agent'
      @agentuuid = nil
      @payload = {}
      # Set last snapshot to 10 minutes ago
      # so we send a snapshot on first report
      @last_snapshot = Time.now - 601
    end

    ##
    # announce_sensor
    #
    # Collect process ID, name and arguments to notify
    # the host agent.
    #
    def announce_sensor
      process = ProcTable.ps(Process.pid)
      announce_payload = {}
      announce_payload[:pid] = Process.pid

      arguments = process.cmdline.split(' ')
      arguments.shift
      announce_payload[:args] = arguments

      path = 'com.instana.plugin.ruby.discovery'
      uri = URI.parse("http://#{@host}:#{@port}/#{path}")
      req = Net::HTTP::Put.new(uri)

      req['Accept'] = 'application/json'
      req['Content-Type'] = 'application/json'
      req.body = announce_payload.to_json

      ::Instana.logger.debug "Announcing sensor to #{path} for pid #{Process.pid}: #{announce_payload.to_json}"

      response = nil
      Net::HTTP.start(uri.hostname, uri.port) do |http|
        response = http.request(req)
      end
      Instana.logger.debug response.code
    rescue => e
      Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
    end

    ##
    # report_entity_data
    #
    # The engine to report data to the host agent
    #
    # TODO: Validate responses
    # TODO: Better host agent check/timeout handling
    #
    def report_entity_data
      path = "com.instana.plugin.ruby.#{Process.pid}"
      uri = URI.parse("http://#{@host}:#{@port}/#{path}")
      req = Net::HTTP::Post.new(uri)

      # Every 5 minutes, send snapshot data as well
      if (Time.now - @last_snapshot) > 600
        @payload[:rubyVersion] = RUBY_VERSION
        @payload[:execArgs] = ['blah']
        @payload[:sensorVersion] = ::Instana::VERSION
        @payload[:pid] = Process.pid
        @payload[:versions] = { :ruby => RUBY_VERSION }
        @last_snapshot = Time.now
      end

      req['Accept'] = 'application/json'
      req['Content-Type'] = 'application/json'
      req.body = @payload.to_json

      Instana.logger.debug "Posting metrics to #{path}: #{@payload.to_json}"

      response = nil
      Net::HTTP.start(uri.hostname, uri.port) do |http|
        response = http.request(req)
      end

      # If we sent snapshot data and the response was Ok,
      # then delete the snapshot data.  Otherwise let it
      # ride for another run.
      if @payload.key?(:rubyVersion) && response.code.to_i == 200
        @payload.delete(:rubyVersion)
        @payload.delete(:execArgs)
        @payload.delete(:sensorVersion)
        @payload.delete(:pid)
        @payload.delete(:version)
      end
      Instana.logger.debug response.code
    rescue => e
      Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
    end

    ##
    # host_agent_ready?
    #
    # Check that the host agent is available and can be contacted.
    #
    def host_agent_ready?
      uri = URI.parse("http://#{@host}:#{@port}/")
      req = Net::HTTP::Get.new(uri)

      req['Accept'] = 'application/json'
      req['Content-Type'] = 'application/json'

      ::Instana.logger.debug "Checking agent availability...."

      response = nil
      Net::HTTP.start(uri.hostname, uri.port) do |http|
        response = http.request(req)
      end

      if response.code.to_i != 200
        Instana.logger.debug "Host agent returned #{response.code}"
        false
      else
        true
      end
    rescue Errno::ECONNREFUSED => e
      Instana.logger.debug "Agent not responding: #{e.inspect}"
      return false
    rescue => e
      Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
      return false
    end
  end
end
