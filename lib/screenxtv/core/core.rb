require 'json'
require 'screenxtv/core/socket'
require 'screenxtv/core/channel'
require 'screenxtv/core/config'

module ScreenXTV

  class ScreenXTVConfig
    attr_accessor :host, :port
    def initialize host, port
      self.host = host
      self.port = port
    end
  end

  CONFIG = ScreenXTVConfig.new 'screenx.tv', 8000

  def self.configure
    yield CONFIG
  end

  def self.HOST
    CONFIG.host
  end

  def self.authenticate user, password
    self.connect do |socket|
      socket.send('init',{user:user,password:password}.to_json)
      type, auth_key = socket.recv
      if type == 'auth'
        auth_key
      end
    end
  end

  def self.connect
    socket = KVSocket.new CONFIG.host, CONFIG.port
    if block_given?
      begin
        result = yield socket
      ensure
        socket.close
      end
    else
      socket
    end
  end

end
