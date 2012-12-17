# -*- coding: utf-8 -*-
require 'pty'
require 'io/console'
require 'socket'
require 'json'
require 'yaml'
require 'optparse'
require 'readline'
require 'tempfile'





if ENV['SCREENXTV_BROADCASTING']
  print "cannot broadcast inside broadcasting screen\n"
  exit
end
ENV['SCREENXTV_BROADCASTING']='1'

Signal.trap(:INT){exit;}

def readline
  s=Readline.readline("> ",true)
  if !s then exit end
  s.strip
end

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
  def socket.recv
    [self.readline.chop,JSON.parse("["+self.readline+"]")[0]]
  end
  socket
end

def stop msg
  height,width=STDOUT.winsize
  print "\e[?1l\e[>\e[1;#{height}r\e[#{height};1H\e[K"
  print msg+"\n"
  exit
end


conf_scan=[
  {
    key:"url",
    msg:"Create a new URL. If given \"foo\", your URL will be \"http://screenx.tv/foo\".",
    value:"",
    match:/^[a-zA-Z0-9_]*$/,
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
  op.on("-u [url]"){|v|argv[:url]=v||true}
  op.on("-c [color]"){|v|argv[:color]=v||true}
  op.on("-t [title]"){|v|argv[:title]=v||true}
  op.on("-reset"){|v|argv[:new]=true}
  op.on("-f config_file"){|v|argv[:file]=v}
end
parser.parse(ARGV)

conf_file=argv[:file] || "#{ENV['HOME']}/.screenxtv.yml"
conf={}
begin
  conf=YAML.load_file conf_file
rescue
end

if argv[:new]
  conf={}
else
  conf['url']=argv[:url]==true ? nil : argv[:url] if argv[:url]
  conf['title']=argv[:title]==true ? nil : argv[:title] if argv[:title]
  conf['color']=argv[:color]==true ? nil : argv[:color] if argv[:color]
end

conf_scan.each do |item|
  key=item[:key]
  msg=item[:msg]
  value=item[:value]
  if !conf[key] then
    if msg then
      print item[:msg]+"\n"
      s=readline
      if s=="" then s=value end
      conf[key]=s
    else
      conf[key]=value
    end
  end
end
conf['url'].gsub! /[^a-zA-Z0-9_]/,""
conf['color'].downcase!
File.write conf_file,conf.to_yaml

print "connecting...\n"
socket=nil
loop do
  File.write conf_file,conf.to_yaml
  socket=kvconnect "screenx.tv",8000
  height,width=STDOUT.winsize
  initdata={
    width:width,height:height,slug:conf['url']+'#'+(conf['urlhash']||''),
    info:{color:conf['color'],title:conf['title']}
  }
  socket.send('init',initdata.to_json)
  key,value=socket.recv
  if key=='slug'
    conf['url'],conf['urlhash']=value.split("#")
    break
  end
  print "Specified url '"+conf['url']+"' is alerady in use. Please set another url.\n"
  conf['url']=readline
end

File.write conf_file,conf.to_yaml

print "Your url is http://screenx.tv/"+conf['url'].split("#")[0]+"\n\n";
print "Press Enter to start broadcasting\n"
readline

screenrc=Tempfile.new("screenrc");
begin
  begin
    File.open("#{ENV['HOME']}/.screenrc"){|file|
      screenrc.write "#{file.read}\n"
    }
  rescue
  end
  screenrc.write "hardstatus alwayslastline 'http://screenx.tv/#{conf['url']}'\n"
  screenrc.flush
rescue
end
p ENV['SCREENRC']=screenrc.path

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
  resized=false
  Thread.new{
    loop do
      sleep 0.1
      if resized
        resized=false
        winsize.call
      end
    end
  }
  Signal.trap(:SIGWINCH){resized=true}
  Signal.trap(:SIGCHLD){stop "broadcast end"}
  Thread.new{
    loop do
      master.write STDIN.getch
    end
  }
  while(data=master.readpartial 1024)
    print data
    socket.send 'data',data
  end
rescue
end
stop "broadcast end"

