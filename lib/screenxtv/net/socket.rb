require 'socket'
require 'json'

module ScreenXTV
  class KVSocket
    def initialize host, port
      @socket = TCPSocket.open host, port
      @mutex = Mutex.new
    end

    def send key, value
      @mutex.synchronize do
        keylen=key.bytesize
        vallen=value.bytesize
        @socket.instance_eval do
          write keylen.chr
          write key
          write (vallen>>8).chr+(vallen&0xff).chr
          write value
        end
      end
    end

    def recv
      key = @socket.readline.chop
      data = @socket.readline
      p key, data
      [key, JSON.parse("["+data+"]")[0]]
    end

    def close
      @mutex.synchronize do
        @socket.close
      end
    end

  end
end
