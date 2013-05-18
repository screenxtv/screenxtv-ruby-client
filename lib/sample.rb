require 'pty'
require 'io/console'
require 'socket'
require 'json'
require 'yaml'
require 'optparse'
require 'readline'
require 'tempfile'
require './lib/screenxtv/net/config'
require './lib/screenxtv/net/channel'
require './lib/screenxtv/commandline/exec'
require './lib/screenxtv/commandline/exec_screen'

ScreenXTV.configure do |config|
  config.host = 'localhost'
  config.port = 8000
end

channel = ScreenXTV::Channel.new
channel.key_updated do |key, value|
  p ['key', key, value]
end

channel.event do |key, value|
  p ['event', key, value]
end

exec_cmd = "bash"
channel.start slug:'6Da1#vTG578cB58WfNUhB', width: 40, height: 20 do |channel|
  #100.times{|i|channel.data "#{i}\r\n";sleep 0.05}
  #ScreenXTV::CommandLine.execute_command channel, exec_cmd
  #ScreenXTV::CommandLine.execute_command_via_screen channel, command:exec_cmd, message:'aaa'
  ScreenXTV::CommandLine.execute_screen channel, command: exec_cmd, message: 'aaa', screen_name: 'hoge'
end

