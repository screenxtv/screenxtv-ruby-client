# -*- coding: utf-8 -*-
require 'pty'
require 'io/console'
require 'socket'
require 'json'
def kvconnect(host,port)
  socket=TCPSocket.open host, port
  def socket.send(key,value)
    keylen=key.bytesize
    vallen=value.bytesize
    self.write keylen.chr+key
    self.write (vallen>>8).chr+(vallen&0xff).chr
    self.write value
  end
  def socket.recv
    [self.readline.chop,JSON.parse("["+self.readline+"]")[0]]
  end
  socket
end

def start
  @sttyoption=`stty -g`
end
def stop
  system "stty "+@sttyoption
  exit
end

################
#definition end#
################


socket=kvconnect "screenx.tv",8000
height,width=STDOUT.winsize
initdata={width:width,height:height,slug:'a#b',info:{color:'black',title:'rubyclient-test'}}
socket.send('init',initdata.to_json)
slug=''
loop do
  key,value=socket.recv
  print key+":"+value+"\n"
  if key=='error'
    p 'An error occured: '+value
    exit
  end
  if key=='slug'
    slug=value
    break
  end
end
p 'your url is http://screenx.tv/'+slug.split("#")[0];
print '> '
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
  ws=STDOUT.winsize
  master.winsize=ws
  ENV['TERM']='vt100'
  ENV['LANG']='ja_JP.UTF-8'
  rr,ww,pid = PTY::getpty("screen -x hoge -R",in:slave,out:master)
  Signal.trap("SIGWINCH"){
    height,width=ws=STDOUT.winsize
    master.winsize=rr.winsize=ws
    socket.send 'winch',{width:width,height:height}.to_json
  }
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


