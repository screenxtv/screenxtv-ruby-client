# -*- coding: utf-8 -*-
require 'pty'
require 'io/console'
require 'socket'
require 'json'
require 'yaml'
require 'optparse'

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
  print "\e[?1l\e[>\e[1;#{height}r\e[#{height};1H"
  system "stty "+@sttyoption
  print msg+"\n"
  exit
end


conf_scan=[
  {
    key:"url",
    msg:"Create a new URL. If given \"foo\", your URL will be \"http://screenx.tv/foo\".",
    value:"",
    match:/^[a-zA-Z0-9]*$/,
    errmsg:'You can use only alphabets, numbers and underscore.'
  },
  {key:"screen",value:"screenxtv"},
  {
    key:"color",msg:"Terminal Color [BLACK/white/green/novel]",
    value:'black',
    option:['black','white','green','novel'],
    errmsg:'unknown color.'
  },
  {key:"title",msg:"Title",value:"no title"},
]

argv={}
parser=OptionParser.new do |op|
  op.on("-u url"){|v|argv[:url]=v}
  op.on("-c color"){|v|argv[:color]=v}
  op.on("-t title"){|v|argv[:title]=v}
  op.on("-e ['uct' to edit]"){|v|argv[:edit]=v||true}
  op.on("-f config_file"){|v|argv[:file]=v}
end
parser.parse(ARGV)

conf_file=argv[:file] || "#{ENV['HOME']}/.screenxtv.yml"
conf={}
begin
  conf=YAML.load_file conf_file
rescue
end

if(argv[:edit])
  if argv[:edit]==true
    conf={}
  else
    conf['title']=nil if argv[:edit].match('t')
    conf['url']=nil if argv[:edit].match('u')
    conf['color']=nil if argv[:edit].match('c')
  end
end
conf['title']||=argv[:title]
conf['url']||=argv[:url]
conf['color']||=argv[:color]

conf_scan.each do |item|
  key=item[:key]
  msg=item[:msg]
  value=item[:value]
  if !conf[key] then
    if msg then
      print item[:msg]+"\n> "
      s=STDIN.readline.strip
      if s=="" then s=value end
      conf[key]=s
    else
      conf[key]=value
    end
  end
end
conf['url'].gsub! /[^a-z^A-Z^0-9^_^#]/,""
conf['color'].downcase!
File.write conf_file,conf.to_yaml

print "connecting...\n"
socket=nil
loop do
  File.write conf_file,conf.to_yaml
  socket=kvconnect "screenx.tv",8000
  height,width=STDOUT.winsize
  initdata={
    width:width,height:height,slug:conf['url'],
    info:{color:conf['color'],title:conf['title']}
  }
  socket.send('init',initdata.to_json)
  key,value=socket.recv
  if key=='slug'
    conf['url']=value
    break
  end
  print "Specified url '"+conf['url']+"' is alerady in use. Please set another url\n> "
  conf['url']=STDIN.readline.strip
end

File.write conf_file,conf.to_yaml

print "Your url is http://screenx.tv/"+conf['url'].split("#")[0]+"\n\n";
print "Press Enter to start broadcasting\n> "
STDIN.readpartial 65536
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
  ENV['LANG']='en_US.UTF-8'
  master.winsize=STDOUT.winsize
  rr,ww,pid = PTY::getpty("screen -x #{conf['screen']} -R",in:slave,out:master)
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
