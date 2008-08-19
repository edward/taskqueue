# Mostly borrowed from http://snippets.dzone.com/posts/show/2265
# Modified by Edward Ocampo-Gooding 2007
# 
# Note that
#   daemon.stop  # (stop the daemon by calling Daemon::Base#stop)
# and
#   stop(daemon) # (stop the daemon's controller by calling Daemon::Controller.stop(daemon))
#                # ^^^ involves terminating the forked daemon process, and removing its pid file
# are two different ordeals entirely
# 
require 'fileutils'

module Daemon
  # WorkingDirectory = File.join(File.dirname(__FILE__), '..')
  WorkingDirectory = File.join(RAILS_ROOT)

  class Base
    def self.pid_fn
      File.join(WorkingDirectory, "log", "#{name}.pid")
    end
    
    def self.daemonize
      Controller.daemonize(self)
    end
  end
  
  module PidFile
    def self.store(daemon, pid)
      File.open(daemon.pid_fn, 'w') {|f| f << pid}
    end
    
    def self.recall(daemon)
      IO.read(daemon.pid_fn).to_i rescue nil
    end
  end
  
  module Controller
    def self.daemonize(daemon)
      case !ARGV.empty? && ARGV[0]
      when 'start'
        start(daemon)
      when 'stop'
        stop(daemon)
      when 'restart'
        stop(daemon)
        start(daemon)
      else
        puts "Invalid command. Please specify start, stop or restart."
        exit
      end
    end
    
    def self.start(daemon)
      fork do
        Process.setsid
        exit if fork
        PidFile.store(daemon, Process.pid)
        Dir.chdir WorkingDirectory
        File.umask 0000
        old_stderr = STDERR
        STDIN.reopen "/dev/null"
        #STDOUT.reopen "/dev/null", "a"
        STDERR.reopen STDOUT
        trap("TERM") {daemon.stop; exit}
        begin
          daemon.start
        rescue
          STDERR.reopen old_stderr
          stop(daemon)
          raise
        end
      end
    end
  
    def self.stop(daemon)
      if !File.file?(daemon.pid_fn)
        puts "Pid file not found. Is the daemon started?"
        exit
      end
      pid = PidFile.recall(daemon)
      FileUtils.rm(daemon.pid_fn)
      pid && Process.kill("TERM", pid)
    end
  end
end