# -*- coding: utf-8 -*-
require 'pty'
require 'io/console'
require 'socket'
require 'json'
require 'yaml'
require 'optparse'
require 'readline'
require 'tempfile'
require 'screenxtv/version'

if `which screen`.empty?
  print %(Warning: you don't have gnu screen in your machine.)
  commands = [
    ['zsh','RPROMPT'=>'(screenxtv)% '],
    ['bash','PS1'=>'bash(screenxtv)$ '],
    ['sh','PS1'=>'sh(screenxtv)$ ']
  ]
  exec_cmd, env = commands.find{|cmd, _| !`which #{cmd}`.empty?}
  env.each{|k,v|ENV[k]=v}
end

def showVersion
  print "ScreenX TV Ruby Client #{ScreenXTV::VERSION}\n" #is there any good way to do this?
  exit
end
def showHelp
  print <<EOS
Usage:
  screenxtv [options]

Options:
  -u, [--url]      # Select a url (e.g. yasulab, tompng)
  -c, [--color]    # Select a color (options: black/white/green/novel)
  -t, [--title]    # Select a title (e.g. Joe's Codestream)
  -r, [--reset]    # Reset your default configuration (e.g. url, color, title)
  -f CONFIG_FILE   # Path to a preset configuration
  -e, [--execute]  # Execute specified Program
  -p, [--private]  # Broadcast your terminal privately (anyone who has the link can access)
  -h, [--help]     # Show this help message and quit
  -v, [--version]  # Show ScreenX TV Ruby Client version number and quit
EOS
  exit
end
HOST="screenx.tv"

def show_info(info)
  broadcasting_url="http://#{HOST}/#{info['url']}"
  private_flag=!!info['private']
  authorized=info['authorized']
  print "Broadcasting URL: \e[1m#{broadcasting_url}\e[m\n"
  print "Chat page       : \e[1m#{broadcasting_url}?chat\e[m\n"
  if info['private']
    print "This is a private casting.\n"
    print "The only person who knows the URL can watch this screen.\n"
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
      print "\r\e[K#{prompt}#{s.gsub /./,'*'}" # delete this
    end
  }
end


def kvconnect(host,port)
  socket=TCPSocket.open host, port
  class << socket
    def init_mutex
      @mutex=Mutex.new
    end
    def send(key,value)
      @mutex.synchronize{
        keylen=key.bytesize
        vallen=value.bytesize
        self.write keylen.chr
        self.write key
        self.write (vallen>>8).chr+(vallen&0xff).chr
        self.write value
      }
    end
    def recv
      [self.readline.chop,JSON.parse("["+self.readline+"]")[0]]
    end
  end
  socket.init_mutex
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
    username=readline "username> "
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
  {key:"screen",value:"screenxtv_public"},
  {key:"screen_private",value:"screenxtv_private"},
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
  op.on("--reset"){|v|argv[:new]=true}
  op.on("-e program"){|v|exec_cmd=v}
  op.on("--execute program"){|v|exec_cmd=v}
  op.on("-p"){|v|argv[:private]=true}
  op.on("--private"){|v|argv[:private]=true}
  op.on("-f config_file"){|v|argv[:file]=v}
  op.on("-v"){showVersion}
  op.on("--version"){showVersion}
  op.on("-h"){showHelp}
  op.on("--help"){showHelp}
end
begin
  parser.parse(ARGV)
rescue
  showHelp
  exit
end

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
  conf['execute']=argv[:execute]==true ? nil : argv[:execute] if argv[:execute]
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
  'authorized'=>conf['urlhash']==url+"/"+(conf['auth_key']||''),
  'private'=>argv[:private]
}
ENV['SCREENXTV_BROADCASTING']=info.to_json
show_info(info)
message="http://#{HOST}/#{info['url']}    #{conf['title']}"

print "\npress enter to start broadcasting"
readline

unless exec_cmd
  unless File.exists? "#{ENV['HOME']}/.screenrc"
    begin
      #disable C-a if not screen user
      Tempfile.open("screenrc_sxtv_alt_conf") do |f|
        f.write "term xterm-256color\n"
        f.write "escape ^Jj\n"
        ENV['SCREENRC']=f.path
      end
    rescue
    end
  end

  begin
    #screenxtv -> screen(target)
    #screenxtv -> screen(hardstatus) -> screen(target)
    status_rc=Tempfile.open("screenrc_sxtv_status") do |f|
      f.write "term xterm-256color\n"
      f.write "hardstatus alwayslastline #{message.inspect}\n"
      f.write "escape ^Qq\n"
      f.write "autodetach off\n"
      next f
    end
  rescue
  end

  screen_name=argv[:private] ? conf['screen_private'] : conf['screen']

  cmd_stat=["screen","-c",status_rc.path,"-S","sx.#{url.gsub('/','.')}.tv"]
  cmd_attach=["screen","-x",screen_name,"-R"]
  exec_cmd=cmd_stat+cmd_attach
end



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
  ENV['LANG']='en_US.UTF-8'
  
  PTY::getpty *exec_cmd do |rr,ww|
    winsize=->{
      height,width=ww.winsize=rr.winsize=STDOUT.winsize
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
        ww.write STDIN.getch
      end
    }
    data=''
    while(data+=rr.readpartial 1024)
      ncount=code=0
      [4,data.length].min.times do
        c=data[data.length-ncount-1]
        code=c.ord
        ncount+=1
        break if code&0x80==0 or code&0x40!=0
      end
      if code&0x80==0 or code&0x40==0
        ncount=0
      elsif code&0x20==0
        ncount=0 if ncount==2
      elsif code&0x10==0
        ncount=0 if ncount==3
      elsif code&0x08==0
        ncount=0 if ncount==4
      elsif code&0x04==0
        ncount=0 if ncount==5
      elsif code&0x02==0
        ncount=0 if ncount==6
      end
      odata=data[0,data.size-ncount]
      print odata
      socket.send 'data',odata
      data=data[data.size-ncount,ncount]
    end
  end
rescue
end
stop "broadcast end"
