require './screenxtv/core/socket'

module ScreenXTV

  class Channel

    def key_updated &block
      @key_updated_callback = block
    end

    def event &block
      @event_callback = block
    end

    def start config, &block
      @socket = ScreenXTV.connect
      @socket.send 'init', config.to_json
      key, value = @socket.recv
      unless key == 'slug' || key == 'private_url'
        @socket.close
        @socket = nil
        throw value
      end

      @key_updated_callback.call key, value

      current = Thread.current
      Thread.new do
        begin
          loop do
            @event_callback.call *@socket.recv
          end
        rescue
        end
        current.exit
      end

      begin
        yield self
      ensure
        @socket.close
      end
    end

    def data odata
      @socket.send 'data', odata
    end

    def winch width, height
      @socket.send 'winch', {width: width, height: height}.to_json
    end

  end

end