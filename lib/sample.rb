require 'pty'
require 'io/console'
require 'socket'
require 'json'
require 'yaml'
require 'optparse'
require 'readline'
require 'tempfile'
require './screenxtv/core/core'
require './screenxtv/commandline/exec'
require './screenxtv/commandline/exec_screen'

ScreenXTV.configure do |config|
  config.host = 'localhost'
  config.port = 8000
end

channel = ScreenXTV::Channel.new
# channel.config_updated do |config|
#   p ['key', config.to_json]
# end

channel.event do |key, value|
  p ['event', key, value]
end

config = ScreenXTV::Config.new
config.private_url = 'suiseiseki'
config.resume_key = 'foobar'


exec_cmd = "bash"
channel.start config do |channel, config|
  message = "http://#{ScreenXTV.HOST}/#{config.url}"
  #100.times{|i|channel.data "#{i}\r\n";sleep 0.05}
  #ScreenXTV::CommandLine.execute_command channel, exec_cmd
  #ScreenXTV::CommandLine.execute_command_via_screen channel, command:exec_cmd, message:message
  ScreenXTV::CommandLine.execute_screen channel, command: exec_cmd, message: message, screen_name: 'hoge'
end

