require './lib/screenxtv/version'
Gem::Specification.new do |s|
  s.name        = 'screenxtv'
  s.version     = ScreenXTV::VERSION
  s.date        = '2017-01-07'
  s.summary     = 'ScreenX TV client'
  s.description = 'Software for broadcasting your terminal to http://screenx.tv/'
  s.author      = 'Tomoya Ishida'
  s.email       = 'tomoyapenguin@gmail.com'
  s.files       = ['lib/screenxtv.rb','lib/screenxtv/version.rb']
  s.executables << 'screenxtv'
  s.homepage    = 'http://screenx.tv/'
end
