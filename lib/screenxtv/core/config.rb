module ScreenXTV
  class Config
    attr_accessor :private, :public_url, :private_url, :resume_key, :anonymous,
                  :width, :height, :title, :color, :username, :auth_key, :session_name
    def initialize
      @width = 80
      @height = 24
    end

    def width= width
      @width = [1, width.to_i].max
    end

    def height= height
      @height = [1, height.to_i].max
    end

    def url
      if private?
        "private/#{private_url}" if private_url
      else
        public_url
      end
    end

    def public?
      !private
    end

    def private?
      !!private
    end

    def private= flag
      @private = !!flag
      if flag
        @public_url = nil
      else
        @private_url = nil
      end
    end

    def public_url= url
      @public_url = url
      if url
        @private_url = nil
        @private = nil
      end
    end

    def private_url= url
      @private_url = url
      if url
        @public_url = nil
        @private = true
      end
    end

    def to_json
      hash = {
        width: width,
        height: height,
        title: title,
        color: color
      }
      if username && auth_key
        hash[:user] = username,
        hash[:auth_key] = auth_key
      end

      if private?
        hash[:private] = true
        hash[:private_url] = "#{private_url}##{resume_key}"
      else
        hash[:slug] = "#{public_url}##{resume_key}"
      end

      hash.each do |key, value|
        hash.delete key if value.nil?
      end
      hash.to_json
    end
  end
end
