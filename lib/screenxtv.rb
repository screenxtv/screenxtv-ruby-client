# -*- coding: utf-8 -*-
require 'pty'
require 'io/console'
require 'socket'
require 'json'
require 'yaml'
require 'optparse'
require 'readline'
require 'tempfile'

HOST="screenx.tv"

def show_info(info)
  broadcasting_url="http://#{HOST}/#{info['url']}"
  private_flag=!!info['private']
  authorized=info['authorized']
  print "broadcasting url : \e[1m#{broadcasting_url}\e[m\n"
  print "your chat page   : \e[1m#{broadcasting_url}?chat\e[m\n"
  if info['private']
    print "This is a private casting.\n"
    print "The only person who knows this URL can watch this screen.\n"
  elsif !info['authorized']
    print "This URL is not reserved and chat messages will be deleted after broadcasting.\n";
    print "If you want to reserve this URL, please create your account.\n"
  end
end

if ENV['SCREENXTV_BROADCASTING']
  show_info(JSON.parse ENV['SCREENXTV_BROADCASTING'])
  exit
end

Signal.trap(:INT){exit;}

def readline(prompt="> ")
  s=Readline.readline(prompt,true)
  if !s then exit end
  s.strip
end
def readpswd(prompt='> ')
  print prompt
  STDIN.raw{
    s=""
    loop do
      c=STDIN.getch
      case c
      when "\x03"
        print "\r\n"
        return nil
      when "\r","\n"
        print "\r\n"
        return s
      when "\x7f"
        if s.length>0
          s=s.slice 0,s.length-1
        else
          print "\a"
        end
      when 'a'..'z','A'..'Z','0'..'9','_'
        s+=c
      else
        print "\a"
      end
      print "\r\e[K#{prompt}#{s.gsub /./,'*'}"
    end
  }
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
  print msg+"\r\n"
  exit
end

def auth(conf)
  loop do
    username=readline "user name> "
    return false if username.size==0
    password=readpswd "password> "
    return false if password.nil? || password.size==0

    socket=kvconnect HOST,8000
    socket.send('init',{user:username,password:password}.to_json)
    key,value=socket.recv
    if key=='auth'
      conf['user']=username
      conf['auth_key']=value
      return true
    end
  end
end

conf_scan=[
  {
    key:"url",
    msg:"Create a new URL. If given \"foo\", your URL will be \"http://#{HOST}/foo\".",
    value:"",
    match:/^[_a-zA-Z0-9]*$/,
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
  op.on("-p"){|v|argv[:private]=true}
  op.on("-private"){|v|argv[:private]=true}
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

conf_scan.delete :url if argv[:private]

conf_scan.each do |item|
  key=item[:key]
  next if key=='url'&&argv[:private]
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
conf['url'].gsub! /[^_a-zA-Z0-9]/,"" if conf['url']
conf['color'].downcase!
File.write conf_file,conf.to_yaml

print "connecting...\n"
socket=nil
url=''
loop do
  File.write conf_file,conf.to_yaml
  socket=kvconnect HOST,8000
  height,width=STDOUT.winsize
  initdata={
    width:width,height:height,slug:(conf['url']||'')+'#'+(conf['urlhash']||''),
    user:conf['user'],
    auth_key:conf['auth_key'],
    private:argv[:private],
    private_url:conf['private_url'],
    info:{color:conf['color'],title:conf['title']}
  }
  socket.send('init',initdata.to_json)
  key,value=socket.recv
  case key
  when 'slug'
    conf['url'],conf['urlhash']=value.split("#")
    url=conf['url']
    break
  when 'private_url'
    conf['private_url']=value;
    url='private/'+value.split("#")[0]
    break
  end
  socket.close
  if value.match /reserved|auth_key/
    print "The url '"+conf['url']+"' is reserved. Please sign in.\n"
    if !auth(conf)
      print "Please set another url.\n"
      conf['url']=readline
    end
  else
    print "Specified url '"+conf['url']+"' is alerady in use. Please set another url.\n"
    conf['url']=readline
  end
end

File.write conf_file,conf.to_yaml
info={
  'url'=>url,
  'authorized'=>conf['urlhash']==url+"/"+conf['auth_key'],
  'private'=>argv[:private] 
}
ENV['SCREENXTV_BROADCASTING']=info.to_json
show_info(info)

print "\npress enter to start broadcasting"
readline

screenrc=Tempfile.new("screenrc");
begin
  begin
    File.open("#{ENV['HOME']}/.screenrc"){|file|
      screenrc.write "#{file.read}\n"
    }
  rescue
  end
  screenrc.write "hardstatus alwayslastline 'http://#{HOST}/#{url}'\n"
  screenrc.flush
rescue
end
ENV['SCREENRC']=screenrc.path

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
