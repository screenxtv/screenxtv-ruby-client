Gem::Specification.new do |s|
  s.name        = 'screenxtv'
  s.version     = '0.0.7'
  s.date        = '2013-02-10'
  s.summary     = 'ScreenX TV client'
  s.description = 'Software for broadcasting your terminal to http://screenx.tv/'
  s.author      = 'Tomoya Ishida'
  s.email       = 'tomoyapenguin@gmail.com'
  s.files       = ['lib/screenxtv.rb']
  s.executables << 'screenxtv'
  s.homepage    = 'http://screenx.tv/'
  s.add_dependency 'json'
end
