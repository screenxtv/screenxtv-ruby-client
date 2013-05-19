module ScreenXTV
  class ConfigFile
    attr_accessor :users, :screens, :private, :defaults, :anonymous

    def initialize file
      @file = file
      load
    end

    def load
      data = nil
      begin
        data = YAML.load_file @file
      rescue
      end
      parse data || {}
      migrate data if data && data['urlhash']
    end

    def update_user username, auth_key
      user = users.find{|u| u[:username] == username}
      if user
        user[:auth_key] = auth_key
      else
        users.push username: username, auth_key: auth_key
      end
    end

    def screen url
      screens.find{|s| s['url'] == url}
    end

    def private_config
      Config.new.tap do |c|
        c.private = true
        c.private_url = @private['url']
        c.title = @private['title']
        c.color = @private['color']
        c.session_name = @private['session_name']
      end
    end

    def public_config url
      Config.new.tap do
        if url.nil? || url.empty?
          info = @anonymous
        else
          info = screen(url) || {}
        end
        c.public_url = info['url']
        c.title = info['title']
        c.color = info['title']
        c.session_name = info['session_name']
      end
    end

    def sym_to_string obj
      if obj.is_a? Hash
        {}.tap do |h|
          obj.each{|k, v| h[k.to_s] = sym_to_string v}
        end
      elsif obj.is_a? Array
        obj.map{|v| sym_to_string v}
      else
        obj
      end
    end

    def save
      File.new @file, 'w' do |f|
        data = {
          defaults: defaults,
          users: users,
          screens: screens,
          private: private,
          anonymous: anonymous
        }
        f.write sym_to_string(data).to_yaml
      end
    end

    def parse data
      defautdata = data['defaults'] || {}
      self.defaults = {
        color: defautdata['color'] || 'black',
        title: defautdata['title'] || 'no title',
        session_name: defautdata['public_session'] || 'screenxtv_public'
      }
      self.users = data['users'].map do |user|
        {username: user['username'], auth_key: user['auth_key']}
      end
      self.screens = data['screens'] || []
      self.anonymous = data['anonymous'] || {}
      self.private = data['private'] || {}
    end

    def migrate olddata
      user, auth_key = olddata['user'], olddata['auth_key']
      self.users.push username: user, auth_key: auth_key if user && auth_key
      url = olddata['url']
      if url
        self.screens = {
          'url' => url,
          'title' => olddata['title'] || 'no_title',
          'color' => olddata['color'] || 'black',
          'resume_key' => olddata['urlhash'],
          'session_name' => olddata['screen'] || 'screenxtv_public'
        }
      end
      private_url = olddata['private_url']
      if private_url
        url, key = private_url.split '#'
        self.private = {
          'url' => url,
          'resume_key' => key,
          'session_name' => olddata['screen_private']
        }
      end
      data['defaults']['color'] = olddata['color']
    end

  end
end
