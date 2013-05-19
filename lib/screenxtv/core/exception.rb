module ScreenXTV
  class URLReservedException
    attr_accessor :url, :username
    def initialize username, url
      self.url = url
      self.username = username
    end
  end

  class URLInUseException
    attr_accessor :url
    def initialize url
      self.url = url
    end
  end
end
