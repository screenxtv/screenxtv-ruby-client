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
        winsize.call
        resized = false
        Thread.new do
          loop do
            sleep 0.1
            if resized
              resized = false
              winsize.call
            end
          end
        end
        Signal.trap(:SIGWINCH){resized = true}
        Signal.trap(:SIGCHLD){}
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
      ncount = code = 0
      [4,data.length].min.times do
        code = data[data.length - ncount - 1].ord
        ncount += 1
        break if code & 0x80 == 0 or code & 0x40 != 0
      end
      blen = 0
      while code & 0x40 == 0
        code <<= 1
        blen += 1
      end
      ncount = 0 if blen <= ncount
      [data[0,data.size-ncount], data[data.size-ncount,ncount]]
    end

    def self.required_fields options, *requireds
      err = requireds.select{|key|options[key].nil?}
      throw "required: #{err}" unless err.empty?
    end
  end
end
