require 'pty'
require 'io/console'

module ScreenXTV
  module CommandLine
    def self.execute_command channel, command
      PTY::getpty *command do |rr,ww|
        winsize = ->{
          height, width = ww.winsize = rr.winsize = STDOUT.winsize
          channel.winch width, height
        }
        resized = false
        Signal.trap(:SIGWINCH){resized = true}
        Signal.trap(:SIGCHLD){}
        winsize.call
        Thread.new do
          loop do
            sleep 0.1
            if resized
              resized = false
              winsize.call
            end
          end
        end
        Thread.new{loop{ww.write STDIN.getch}}
        begin
          prevdata = ''
          while(data = rr.readpartial 1024)
            odata, prevdata = utf8_split prevdata + data
            channel.data odata
            print odata
          end
        rescue
        end
      end
    end

    def self.utf8_split data
      ncount = blen = code = 0
      [5,data.length].min.times do
        code = data[data.length - ncount - 1].ord
        break if code & 0x80 == 0 || code & 0x40 != 0
        ncount += 1
      end
      if code & 0x80 == 0
        return [data[0, data.size - ncount], data[data.size - ncount, ncount]]
      end
      while code & 0x40 != 0
        code <<= 1
        blen += 1
      end
      ncount += 1
      ncount = 0 if blen < ncount
      [data[0, data.size - ncount], data[data.size - ncount, ncount]]
    end

    def self.required_fields options, *requireds
      err = requireds.select{|key|options[key].nil?}
      throw "required: #{err}" unless err.empty?
    end
  end
end
