# require AR
require 'rubygems'
require 'active_record'

# connect to the database (sqlite in this case)
ActiveRecord::Base.establish_connection({
      :adapter => "sqlite3", 
      :dbfile => "db/database.sqlite3"
})

class CreateEvent < ActiveRecord::Migration
  def self.up
    create_table :events do |t|
      t.string :title
      t.string :creator
      t.string :channel
      t.datetime :time
    end
  end
  
  def self.down
    drop_table :events
  end
end

class CreateTask < ActiveRecord::Migration
  def self.up
    create_table :tasks do |t|
      t.string :title
      t.string :assignee
      t.string :assigner
      t.boolean :complete, :default => false
    end
  end
  def self.down
    drop_table :tasks
  end
end

# run the migration
CreateEvent.migrate(:up)
CreateTask.migrate(:up)