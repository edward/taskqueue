require 'fileutils'

RAILS_ROOT = File.dirname(__FILE__) + '/../../..'

# Copy over the task_queue_daemon [start|stop] script
FileUtils.cp(File.join(File.dirname(__FILE__), 'script/task_queue_daemon'), "#{RAILS_ROOT}/script/task_queue_daemon")
File.chmod(0755, "#{RAILS_ROOT}/script/task_queue_daemon")

# Append example TaskQueueFailureNotifier configuration to environment.rb
File.open("#{RAILS_ROOT}/config/environment.rb", 'a') do |f|
  f << "

# notify me when my tasks fail to execute
TaskQueueFailureNotifier.failure_recipients = %w(some_lucky_dev@place.com another_poor_person@somewhere.com)
TaskQueueFailureNotifier.sender_address = 'noreply@place.com'"
end

# Copy over the task_queue_daemon configuration file
FileUtils.cp(File.join(File.dirname(__FILE__), 'config/task_queue_daemon.yml'), "#{RAILS_ROOT}/config/task_queue_daemon.yml")
FileUtils.mkdir_p("#{RAILS_ROOT}/app/views/task_queue_failure_notifier")
FileUtils.cp(File.join(File.dirname(__FILE__), 'app/views/task_queue_failure_notifier/failure_notification.rhtml'), "#{RAILS_ROOT}/app/views/task_queue_failure_notifier/failure_notification.rhtml")

# Display the README
puts IO.read(File.join(File.dirname(__FILE__), 'README'))
