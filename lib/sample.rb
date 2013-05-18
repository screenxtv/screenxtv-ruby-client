# -*- coding: utf-8 -*-
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

channel.start slug:'fZaB#tDRdJBDnKPq2wdLE', width:40, height:20 do |channel|
  20.times do |i|
    channel.data "#{i}\r\n";
    sleep 1
  end
end

