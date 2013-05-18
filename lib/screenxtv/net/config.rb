require 'json'
require './lib/screenxtv/net/socket'

module ScreenXTV

  class NetworkConfig
    attr_accessor :host, :port
    def initialize host, port
      self.host = host
      self.port = port
    end
  end

  CONFIG = NetworkConfig.new 'screenx.tv', 8000

  def self.configure
    yield CONFIG
  end

  def self.authenticate user, password
    self.connect do |socket|
      socket.send('init',{user:username,password:password}.to_json)
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
