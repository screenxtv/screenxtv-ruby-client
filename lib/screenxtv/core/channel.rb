require './screenxtv/core/socket'
require './screenxtv/core/exception'

module ScreenXTV

  class Channel

    def config_updated &block
      @config_updated_callback = block
    end

    def event &block
      @event_callback = block
    end

    def start config, users={}, &block
      if config.username
        user = users[config.username]
        config.auth_key = user.auth_key if user
      end
      begin
        @socket = start_init config
      rescue URLReservedException => e
        user = users[e.username]
        if user && config.username != e.username
          config.username = user.name
          config.auth_key = user.auth_key
          retry
        else
          config.username = nil
          raise e
        end
      rescue URLInUseException => e
        if config.anonymous
          config.username = nil
          config.auth_key = nil
          if config.private?
            config.private_url = nil
          else
            config.public_url = nil
          end
          retry
        else
          raise e
        end
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

    private
    def start_init config
      socket = ScreenXTV.connect
      socket.send 'init', config.to_json
      key, value = socket.recv
      if key == 'slug' || key == 'private_url'
        url, resume_key = value.split "#"
        changed = false
        if config.private?
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
        socket
      else
        socket.close
        url = config.private? ? config.private_url : config.public_url
        if /reserved.*:(?<username>.+)/ =~ value
          raise URLReservedException username, url
        elsif value.match /in.*use/
          raise URLInUseException url
        else
          raise Exception, value
        end
      end
    end

  end
end