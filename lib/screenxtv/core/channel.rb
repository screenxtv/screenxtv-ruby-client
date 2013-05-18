require './screenxtv/core/socket'

module ScreenXTV

  class Channel

    def config_updated &block
      @config_updated_callback = block
    end

    def event &block
      @event_callback = block
    end

    def start config, &block
      @socket = ScreenXTV.connect
      @socket.send 'init', config.to_json
      key, value = @socket.recv
      if key == 'slug' || key == 'private_url'
        url, resume_key = value.split "#"
        changed = false
        if config.private
          if config.private_url != url
            config.private_url = url
            changed = true
          end
        else
          if config.public_url != url
            config.public_url = url
            changed = true
          end
        end
        if config.resume_key != resume_key
          config.resume_key = resume_key
          changed = true
        end
        @config_updated_callback.call config if changed && @config_updated_callback
      else
        @socket.close
        throw value
      end

      current = Thread.current
      Thread.new do
        begin
          loop do
            @event_callback.call *@socket.recv if @event_callback
          end
        rescue
        end
        current.exit
      end

      begin
        yield self, config
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