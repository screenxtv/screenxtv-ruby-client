require 'json'
class Recorder
  def initialize filename,info
    @time=Time.now
    @file=File.open filename,'w'
    @file.write File.read('./record.html')
    @file.write "<script>info=#{info.to_json};</script>\n"
  end
  def self.open(file,info)
    if block_given?
      rec=self.new file,info
      yield rec
      rec.close
    else
      self.new file,info
    end
  end
  def write hash
    hash[:time]=Time.now-@time
    @file.write "<script>data.push(#{hash.to_json})</script>\n"
  end
  def close
    @file.close
  end
end
