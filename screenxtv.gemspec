Gem::Specification.new do |s|
  s.name        = 'screenxtv'
  s.version     = '0.0.4'
  s.date        = '2012-12-11'
  s.summary     = 'ScreenX TV client'
  s.description = 'Software for broadcasting your terminal to http://screenx.tv/'
  s.author      = 'Tomoya Ishida'
  s.email       = 'tomoyapenguin@gmail.com'
  s.files       = ['lib/screenxtv.rb']
  s.executables << 'screenxtv'
  s.homepage    = 'http://screenx.tv/'
  s.add_dependency 'io-console'
  s.add_dependency 'json'
end
