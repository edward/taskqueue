require File.dirname(__FILE__) + '/../../../../spec/spec_helper'

describe TaskQueue do
  
  it "should be a TaskQueue" do
    TaskQueue.new.should be_an_instance_of(TaskQueue) 
  end
  
  it "should inherit from ActiveRecord" do
    TaskQueue.new.should be_kind_of(ActiveRecord::Base)
  end
end

describe TaskQueue, 'scheduler' do
  
  before(:each) do
    @foo = mock_model(TaskQueue)
    @foo.stub!(:respond_to?).and_return(true)
  end 
  
  it "should schedule a task for a given object" do
    @foo.should_receive(:respond_to?).with(:bar, false).and_return(true)
    
    task = TaskQueue.schedule(@foo, :bar)
    
    task.resource.id.should == @foo.id
    task.method_name.should == :bar
    
    task.should_not be_new_record
  end
  
  it "should not schedule an invalid task" do
    TaskQueue.schedule(@foo, nil).should == false
  end
  
  it "should accept arguments for task methods when scheduling" do
    arguments = ["first argument", "second argument"]
    
    @foo.should_receive(:respond_to?).with(:bar, false).and_return(true)

    task = TaskQueue.schedule(@foo, :bar, arguments)
    task.arguments.should == arguments
  end
  
  it "should accept an ActiveRecord instance as an argument when scheduling" do
    arguments = TaskQueue.create(:method_name => 'new', :klass => 'Array')
    
    @foo.should_receive(:respond_to?).with(:bar, false).and_return(true)

    task = TaskQueue.schedule(@foo, :bar, arguments)
    task.reload.arguments.should == arguments
  end

  it "should be able to store class methods" do
    task = TaskQueue.schedule(User, :find)
    task.klass.should == "User"
  end
end

describe TaskQueue, 'executer' do
  it "should execute tasks" do
    payload = mock_model(TaskQueue)
    payload.should_receive(:send).with(:to_salesforce, :arg1, :arg2)
    
    # Have to do this manually so to avoid AR-related pain with #save
    # task = TaskQueue.schedule(payload, :to_salesforce, Time.now)
    
    tq = TaskQueue.new
    tq.resource = payload
    tq.arguments = [:arg1, :arg2]
    tq.method_name = :to_salesforce

    tq.should_receive(:resource).and_return(payload)
    tq.execute
  end
  
  it "should execute current tasks (those with execute_at time <= now)" do
    task = mock_model(TaskQueue)
    task.should_receive(:execute)

    # specify the time for find
    now = Time.now
    Time.stub!(:now).and_return(now)
    TaskQueue.should_receive(:find).with(:all, :order => "execute_at asc", :conditions => ["execute_at <= ?", now]).and_return([task])

    TaskQueue.execute_current
  end

  it "should reschedule on failed executions" do
    # If execution fails, we should reschedule the task for a late time.
    # 
    # The delay to reschedule should be based on the number of retries, 
    # eg: first retry in 2 minutes, the next 4 minutes ... up to ~17 hours (1024 minutes)
    # 
    # If MAX_RETRIES is reached, execution should be flagged as failed and the admin should be notified
    
    payload = mock_model(TaskQueue)
    payload.stub!(:some_failing_method)
    payload.should_receive(:send).with(:some_failing_method, nil).and_raise(StandardError)
    
    tq = TaskQueue.new
    tq.resource = payload
    tq.method_name = :some_failing_method
    
    tq.should_receive(:reschedule_due_to_failure)
    tq.should_receive(:save!)
    
    tq.execute
  end
  
  it "should reschedule in increments of 2 ** (number of times rescheduled)" do
    tq = TaskQueue.new
    tq.times_rescheduled = 0
    
    original_time = Time.now
    
    tq.execute_at = original_time
    
    tq.send(:reschedule_due_to_failure)
    tq.times_rescheduled.should == 1
    tq.execute_at.should == original_time + 2.minutes
  end
  
  it "should notify the admins if the task fails MAX_RETRIES times" do
    payload = mock_model(TaskQueue)
    # payload.should_receive(:send).with(:to_salesforce, :arg1, :arg2)
    
    tq = TaskQueue.new
    tq.resource = payload
    tq.arguments = [:arg1, :arg2]
    tq.method_name = :to_salesforce
    tq.execute_at = Time.now
    
    tq.times_rescheduled = TaskQueue::MAX_RETRIES - 1
    
    # Trigger an exception to be seen in the email
    begin
      raise "An exception thrown on a failed method execution"
    rescue StandardError
      # no-op
    end
    
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    
    original_time = tq.execute_at
    
    # TaskQueueFailureNotifier.should_receive(:deliver_failure_notification)
    
    tq.send(:reschedule_due_to_failure)
    
    # The following should probably be broken out to TaskQueueFailureNotifier's own spec
    
    ActionMailer::Base.deliveries.size.should == 1
    email = ActionMailer::Base.deliveries.first
    email.to.should == TaskQueueFailureNotifier.failure_recipients
    email.from.should == [TaskQueueFailureNotifier.sender_address]
    email.subject.should == "#{TaskQueueFailureNotifier.email_prefix}#{tq.resource}.#{tq.method_name.to_s}(#{tq.arguments.join(", ")}) : (#{$!})"
    
    email.body.include?("#{tq.resource}.#{tq.method_name.to_s}(#{tq.arguments.join(", ")})").should be_true
    
    # Not sure why this one is giving out different timestamps
    email.body.include?("#{original_time - (2 ** tq.times_rescheduled).minutes}").should be_true
    
    email.body.include?("#{$!}").should be_true
  end
  
end
