# connect to the database
ActiveRecord::Base.establish_connection({
      :adapter => "sqlite3", 
      :dbfile => "db/database.sqlite3"
})

class Task < ActiveRecord::Base
end
class Event < ActiveRecord::Base
end
