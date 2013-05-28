module ScreenXTV
  class URLReservedException < Exception
    attr_accessor :url, :username
    def initialize url, username
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
