# Schedules tasks to be executed asynchronously at a scheduled time
#
# Example usage:
#
#   c = Customer.find :first
#   TaskQueue.schedule c, :to_salesforce, Date.today+1
#
class TaskQueue < ActiveRecord::Base
  belongs_to :resource, :polymorphic => true

  serialize :method_name  # just in case it's a symbol
  
  MAX_RETRIES = 10

  def arguments
    self[:arguments] ? load_arguments : nil
  end
  
  def arguments=(args)
    self[:arguments] = Marshal.dump(args)
  end

  def self.schedule(resource, method_name, args = nil, time=Time.now)
    # check if the class type is of AR (means it's a resource)
    # otherwise, store it as a Klass (so it's a Class method)
    
    tq = TaskQueue.new
    
    tq.times_rescheduled = 0
    
    # method_name = method_name.to_s if method_name.is_a? Symbol
    
    if resource.is_a?(Class)
      tq.klass = resource.to_s
    else
      tq.resource = resource
    end
    
    tq.method_name = method_name
    tq.execute_at = time
    tq.arguments = args
        
    tq.save && tq
  end
  
  # Won't work because to_yaml_properties expects @marked instance_variables
  #
  #   TypeError: {"arguments"=>nil, "execute_at"=>nil, "klass"=>"User", 
  #               resource_type"=>nil, "resource_id"=>nil, 
  #               "method_name"=>"find"} is not a symbol
  #
  #
  # def to_yaml_properties
  #   @attributes = {"resource_type" => resource && resource.class,
  #                  "klass" => klass && klass.to_s,
  #                  "execute_at" => execute_at,
  #                  "arguments" => arguments,
  #                  "resource_id" => resource && resource.id,
  #                  "method_name" => method_name}
  #   @new_record = self.new_record?
  #   [@attributes, @new_record]
  # end
  
  def next_task
    find(:first, :order => "execute_at asc")
  end
  
  # What's a better name for this method?
  def next_tasks
    find(:all, :order => "execute_at asc")
  end
  
  def execute
    begin
      if klass
        # Would work if to_yaml_properties worked
        # klass.send(method_name, *arguments)
        
        # eval "#{klass}.#{method_name}(*arguments)"
        msg = Object.const_get(klass).send(method_name, *arguments)
      else
        resource.send(self.method_name, *arguments)
      end
      destroy
    rescue StandardError
      reschedule_due_to_failure
      save!
    end
  end
  
  def self.execute_current
    begin
      tasks = find(:all, :order => "execute_at asc", :conditions => ["execute_at <= ?", Time.now])
    rescue Exception => e
      if e.message =~ /Mysql::Error: #42S02Table/
        $stderr.puts "\n" + "=" * 78 + 
                     "\nThe task_queue table could not be found; please run its migration to create it\n" +
                     "=" * 78
      end
      raise e
    end
    
    tasks.each do |t| 
      t.execute
    end
  end
  
  private
  
  def load_arguments
    begin
      Marshal.load(self[:arguments])
    rescue ArgumentError => e
      
      # If an exception is raised during Marshal.load of the arguments (i.e. if
      # the arguments include classes within a marshalled (serialized)
      # ActiveRecord objects that haven't been loaded through mod.autoload or
      # whatever) it can't find the class), then attempt to load it by reading
      # the exception: "undefined class/module SomeClass")
      if e.to_s =~ /undefined class\/module/
        TaskQueue.const_get(e.to_s.split.last)
        load_arguments
      else
        e
      end
    end
  end

  def reschedule_due_to_failure
    self.times_rescheduled += 1
    
    if times_rescheduled >= MAX_RETRIES
      # Notify the admins with the last exception seen 
      # (hopefully we won't run into concurrency problems with $!)
      unless TaskQueueFailureNotifier.deliver_failure_notification(self, $!)
        raise "Unable to send TaskQueue failure notice; does " +
              "app/views/task_queue_failure_notifier/failure_notification.rhtml exist?"
      end
    end
    
    # Push execute_at back by 2 ** times_rescheduled
    self.execute_at += (2 ** self.times_rescheduled).minutes
  end
  
  # validates_presence_of :method_name
  def method_name_invalid?
    return true if method_name.nil?
    
    if klass
      # return true unless klass.respond_to? method_name
      # eval "#{klass}.respond_to? :#{method_name}"
      Object.const_get(klass).respond_to?(method_name)
    else
      return true unless resource.respond_to? method_name
    end
    
    false
  end
  
  def validate
    errors.add(:method_name) if method_name_invalid?
  end
end
