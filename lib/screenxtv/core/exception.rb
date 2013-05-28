module ScreenXTV
  class URLReservedException < Exception
    attr_accessor :url, :username
    def initialize username, url
      self.url = url
      self.username = username
    end
  end

  class URLInUseException < Exception
    attr_accessor :url
    def initialize url
      self.url = url
    end
  end
end
