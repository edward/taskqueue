class TaskQueueMigration < ActiveRecord::Migration
  def self.up
    create_table :task_queues do |t|
      t.column :resource_id, :integer
      t.column :resource_type, :string
      t.column :execute_at, :datetime
      t.column :method_name, :string
      t.column :arguments, :binary, :limit => 1.megabyte
      t.column :klass, :string
      t.column :times_rescheduled, :integer, :default => 0
    end
  end

  def self.down
    drop_table :task_queues
  end
end
