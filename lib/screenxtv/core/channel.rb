require 'screenxtv/core/socket'
require 'screenxtv/core/exception'

module ScreenXTV

  class Channel

    def event &block
      @event_callback = block
    end

    def start config, users = [], &block
      if config.username
        user = users.find{|u| u[:username] == config.username}
        config.auth_key = user[:auth_key] if user
      end
      retry_count = 0
      begin
        retry_count += 1
        @socket = start_init config
      rescue URLReservedException => e
        config.username = e.username
        user = users.find{|u| [:username] == e.username}
        raise e if user.nil? || retry_count >= 2
        config.auth_key = user[:auth_key]
        retry
      rescue URLInUseException => e
        raise e unless config.anonymous || retry_count >= 2
        config.username = nil
        config.auth_key = nil
        config.private_url = nil
        config.public_url = nil
        retry
      end

      current = Thread.current
      Thread.new do
        begin
          loop do
            event = @socket.recv
            @event_callback.call *event if @event_callback
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
        config.resume_key = resume_key
        if config.private?
          config.private_url = url
        else
          config.public_url = url
        end
        unless config.public_url && resume_key.include?(config.public_url)
          config.username = nil
          config.auth_key = nil
        end
        socket
      else
        socket.close
        url = config.private? ? config.private_url : config.public_url
        if /reserved.*:(?<username>.+)/ =~ value
          raise URLReservedException.new url, username
        elsif value.match /in.*use/
          raise URLInUseException.new url
        else
          raise Exception, value
        end
      end
    end

  end
end