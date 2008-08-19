class TaskQueueFailureNotifier < ActionMailer::Base
  @@sender_address = %("TaskQueue Failure Notifier" <task.failure.notifier@default.com>)
  cattr_accessor :sender_address

  @@failure_recipients = []
  cattr_accessor :failure_recipients

  @@email_prefix = "[EXECUTION FAILURE] "
  cattr_accessor :email_prefix
  
  def failure_notification(tq, exception)
    arguments   = tq.arguments ? tq.arguments.join(", ")[0..50] : ""
    method_name = tq.method_name.to_s

    subject    "#{email_prefix}#{tq.resource}.#{method_name}(#{arguments}) : (#{exception})"

    recipients failure_recipients
    from       sender_address
    
    @body = {:tq           => tq,
             :exception    => exception,
             :email_prefix => TaskQueueFailureNotifier::email_prefix }
  end
end
