# -*- coding: utf-8 -*-
require 'pty'
require 'io/console'
require 'socket'
require 'json'
require 'yaml'
def kvconnect(host,port)
  socket=TCPSocket.open host, port
  @@mutex=Mutex.new
  def socket.send(key,value)
    @@mutex.synchronize{
      keylen=key.bytesize
      vallen=value.bytesize
      self.write keylen.chr
      self.write key
      self.write (vallen>>8).chr+(vallen&0xff).chr
      self.write value
    }
  end
  def socket.lockhoge
    sleep 1
  end
  def socket.recv
    [self.readline.chop,JSON.parse("["+self.readline+"]")[0]]
  end
  socket
end

def start
  @sttyoption=`stty -g`
end
def stop msg
  height,width=STDOUT.winsize
  print "\e[?1l\e[>\e[#{height};1H"
  system "stty "+@sttyoption
  print msg+"\n"
  exit
end


conf_scan=[
  {key:"url",msg:"Create a new URL. If given \"foo\", your URL will be \"http://screenx.tv/foo\".",value:""},
  {key:"screen",value:"screenxtv"},
  {key:"color",msg:"Terminal Color [BLACK/white/green/novel]",value:"black"},
  {key:"title",msg:"Title",value:"no title"},
#  {key:"private",msg:"Would you like to make it private? [NO/yes]",value:"no"}
]

conf_file="screenxtv.yml"
conf={}
begin
  conf=YAML.load_file conf_file
rescue
end

conf_scan.each do |item|
  key=item[:key]
  msg=item[:msg]
  value=item[:value]
  if !conf[key] then
    if msg then
      print item[:msg]+"\n> "
      s=STDIN.readline.chop
      if s=="" then s=value end
      conf[key]=s
    else
      conf[key]=value
    end
  end
end
conf['url'].gsub! /[^a-z^A-Z^0-9^_^#]/,""
conf['color'].downcase!
conf['private'].downcase!
File.write conf_file,conf.to_yaml

print "connecting...\n"

socket=kvconnect "screenx.tv",8000
height,width=STDOUT.winsize
initdata={
  width:width,height:height,slug:conf['url'],
  info:{color:conf['color'],title:conf['title']}
}
socket.send('init',initdata.to_json)
url=nil
loop do
  key,value=socket.recv
  if key=='error'
    print 'An error occured: '+value
    exit
  end
  if key=='slug'
    url=value
    break
  end
end

conf['url']=url
File.write conf_file,conf.to_yaml

print "your url is http://screenx.tv/"+url.split("#")[0]+"\n\n";
print "Press Enter to start broadcasting "
STDIN.readline
start
Thread.new{
  begin
    loop do
      key,value=socket.recv
    end
  rescue
  end
  stop "connection closed"
}

begin
  system "stty raw"
  master,slave=PTY.open
  ENV['TERM']='vt100'
  ENV['LANG']='ja_JP.UTF-8'
  master.winsize=STDOUT.winsize
  rr,ww,pid = PTY::getpty("screen -x hoge -R",in:slave,out:master)
  winsize=->{
    height,width=master.winsize=rr.winsize=STDOUT.winsize
    socket.send 'winch',{width:width,height:height}.to_json
  }
  winsize.call
  Signal.trap("SIGWINCH"){Thread.new{winsize.call}}
  Signal.trap("SIGCHLD"){stop "broadcast end"}
  Thread.new{
    loop do
      master.write STDIN.getc
    end
  }
  while(data=master.readpartial 1024)
    print data
    socket.send 'data',data
  end
rescue
end
stop "broadcast end"


