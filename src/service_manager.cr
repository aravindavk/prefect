require "json"
require "log"

module ServiceManager
  struct Service
    include JSON::Serializable

    property name = "", path = "", args = [] of String, pid = 0, signal = 0, restart = false, auto_restart = false

    def initialize(@name)
    end
  end

  class_property services = Hash(String, Service).new
  @@watching = false
  @@svc_dir = ""
  @@processes = Hash(String, Process).new

  def self.watch_services
    new_svcs = [] of String

    Dir.children(@@svc_dir).each do |svc_file|
      next unless svc_file.ends_with?(".json")

      svc = Service.from_json(File.read("#{@@svc_dir}/#{svc_file}"))

      existing_svc = @@services[svc.name]?
      if existing_svc.nil?
        handle_new(svc)
      elsif existing_svc != svc
        handle_modified(existing_svc, svc)
      else
        handle_auto_restart(svc)
      end
      new_svcs << svc.name
    end

    @@services.each do |key, svc|
      unless new_svcs.includes?(key)
        handle_deleted(svc)
      end
    end
  end

  def self.handle_auto_restart(svc)
    return unless svc.auto_restart

    unless running?(svc.name)
      proc = @@processes[svc.name]?
      if proc
        proc.wait
        @@processes.delete(svc.name)
      end

      start_service(svc)
    end
  end

  private def self.running?(svc_name)
    proc = @@processes[svc_name]?
    return false unless proc

    # exists? returns true even for Zombie processes. /proc/<pid>/cmdline
    # will be empty if it is zombie process.
    Process.exists?(proc.pid.to_i) && File.read("/proc/#{proc.pid}/cmdline") != ""
  end

  private def self.start_service(svc)
    return if running?(svc.name)
    Log.info &.emit("Starting the service", name: svc.name, path: svc.path, args: svc.args)

    proc = Process.new(svc.path, svc.args)
    @@processes[svc.name] = proc
  rescue File::NotFoundError
    Log.error &.emit("Failed to start the service", name: svc.name, path: svc.path, args: svc.args)
  end

  private def self.stop_service(svc)
    proc = @@processes[svc.name]?
    return unless proc

    proc.terminate
    @@processes.delete(svc.name)
  end

  private def self.restart_service(svc)
    stop_service(svc)
    start_service(svc)
  end

  private def self.signal_service(svc, sig)
    proc = @@processes[svc.name]?
    return unless proc

    proc.signal(Signal.from_value(sig))
  end

  def self.wait_services
    @@processes.each do |_key, proc|
      proc.wait
    end
  end

  def self.handle_new(svc)
    Log.info &.emit("NEW service", name: svc.name, path: svc.path, args: svc.args)
    @@services[svc.name] = svc
    start_service(svc)
  end

  def self.handle_modified(existing_svc, svc)
    # Service args changed
    if existing_svc.args != svc.args
      Log.info &.emit("MODIFY", name: svc.name, existing_path: existing_svc.path,
        path: svc.path, existing_args: existing_svc.args, args: svc.args)
      stop_service(existing_svc)
      start_service(svc)
    end

    # Restart requested
    if svc.restart
      restart_service(svc)
      Log.info &.emit("RESTART", name: svc.name)
    end

    # Send signal
    if svc.signal != 0
      signal_service(svc, svc.signal)
      Log.info &.emit("SIGNAL", name: svc.name, signal: Signal.from_value(svc.signal).to_s)
    end

    @@services[svc.name] = svc

    # Reset the service file content
    if svc.signal != 0 || svc.restart
      svc.restart = false
      svc.signal = 0
      File.write("#{@@svc_dir}/#{svc.name}.json", svc.to_json)
    end
  end

  def self.handle_deleted(svc)
    Log.info &.emit("DELETE", name: svc.name)

    @@services.delete(svc.name)
    stop_service(svc)
  end

  def self.watch
    loop do
      break unless @@watching
    end

    @@watching = true
    watch_services
    @@watching = false
  end

  def self.run(svc_dir)
    @@svc_dir = svc_dir

    if @@svc_dir == ""
      Log.error { "svc_dir is not provided" }
      return
    end

    Dir.mkdir_p @@svc_dir

    # Update self PID
    File.write("#{@@svc_dir}/pid", "#{Process.pid}")

    Signal::INT.trap do
      wait_services
      exit 1
    end

    Signal::HUP.trap do
      Log.info { "Received reload signal" }
      watch
      status = Hash(String, Bool).new
      @@services.each do |_key, svc|
        status[svc.name] = running?(svc.name)
      end
      File.write("#{@@svc_dir}/status", status.to_json)
    end

    loop do
      watch
      sleep 60.seconds
    end
  end
end
