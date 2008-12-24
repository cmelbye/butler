class Configuration
  def initialize( file = 'config.yaml' )
    @config = YAML.load_file( file )
  end
  
  def is_admin?(nick, host)
    for person in @config
      if person['nick'] == nick && person['host'] == host
        return true
      end
    end
    return false
  end
end