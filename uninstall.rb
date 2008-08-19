require 'fileutils'

RAILS_ROOT = File.dirname(__FILE__) + '/../../..'

begin
  # Remove the task_queue_daemon [start|stop] script
  FileUtils.rm("#{RAILS_ROOT}/script/task_queue_daemon")
rescue
  # No-op; if we're running this twice, it's ok
end

begin
  backup_copy = File.read("#{RAILS_ROOT}/config/environment.rb")
  
  # Comment-out lines that start with 'TaskQueueFailureNotifier' in environment.rb
  File.open("#{RAILS_ROOT}/config/environment.rb", 'r+') do |file|
    lines = file.readlines
    lines.each do |line|
      line.gsub!(/^TaskQueueFailureNotifier/, '# TaskQueueFailureNotifier')
    end
  
    file.pos = 0
    file.print lines
    file.truncate(file.pos)
  end
rescue
  # Try to restore environment.rb and re-raise
  File.open("#{RAILS_ROOT}/config/environment.rb", 'w') do |file|
    file.print(backup_copy)
  end
  
  $stderr.print "An error occurred while commenting-out " +
            "TaskQueueFailureNotifier lines in config/environment.rb during uninstallation"
  raise
end

begin
  # Remove the task_queue_daemon configuration file
  FileUtils.rm("#{RAILS_ROOT}/config/task_queue_daemon.yml")
  
  # Remove the failure notification view
  FileUtils.rm_r("#{RAILS_ROOT}/app/views/task_queue_failure_notifier", :secure => true)
rescue
  # No-op; if we're running this twice, it's ok
end