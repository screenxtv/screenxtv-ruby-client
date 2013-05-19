module ScreenXTV
  module CLI
    OPTIONS = [
      [:private,'private broadcasting'],
      [:url,'specify url'],
      [:,'specify url'],
      [:help,'show help'],
    ]

    def self.option_parse argv
      args = []
      ops = []
      argv.each do |s|
        if /--?(?<arg>[a-z]+)/ =~ s
          ops.push [arg]
        elsif options.empty?
          args.push s
        else
          ops.last.push s
        end
      end
      options = {}
      ops.each do |key, *values|
        op = OPTIONS.find{|op| op.to_s.include? key}
        raise Exception, "invalid option '#{key}'" if op.nil?
        options[op] = values.empty? true : values
      end
    end

    def self.start argv
      begin
        args, options = option_parse argv
      rescue
      end

      conffile = ConfigFile.new "#{ENV['HOME']}/.screextv.yml"
      defaults = conffile.defaults
      if options[:private]
        config = conffile.private_config
      elsif options[:url]
        config = conffile.public_config options[:url]
      else
        url = ask 'url'
        config = conffile.public_config url
      end
      fill_config config

      
      routine = ->(channel, config){
        message = "http://#{ScreenXTV.HOST}/#{config.url}"
        ScreenXTV::CommandLine.execute_screen channel, command: exec_cmd, message: message, screen_name: 'hoge'
      }
      begin
        channel = ScreenXTV::Channel.new
        channel.start config, conffile.users, &routine
      rescue URLReservedException => e
        auth_key = authenticate e.username
        if auth_key
          conffile.update_user e.username, auth_key
          retry
        end
        exit
      rescue URLInUseException => e
        print "URL IN USE"
        config = conffile.public_config url
        
        retry
        exit
      end
    end
  end
end
