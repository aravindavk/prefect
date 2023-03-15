require "json"
require "log"

module ServiceManager
  struct Service
    include JSON::Serializable

    property name = "", args = [] of String, pid = 0
  end

  class_property services = Hash(String, Service).new
  @@watching = false
  @@svc_dir = ""

  def self.watch_services
    new_svcs = [] of String

    Dir.children(@@svc_dir).each do |svc_file|
      next unless svc_file.ends_with?(".json")

      svc = ServiceManager::Service.from_json(File.read("#{@@svc_dir}/#{svc_file}"))

      existing_svc = ServiceManager.services[svc.name]?
      if existing_svc.nil?
        ServiceManager.handle_new(svc)
      elsif existing_svc != svc
        ServiceManager.handle_modified(existing_svc, svc)
      else
        Log.debug { "No change detected. SVC=#{svc.name}" }
      end
      new_svcs << svc.name
    end

    ServiceManager.services.each do |key, svc|
      unless new_svcs.includes?(key)
        ServiceManager.handle_deleted(svc)
      end
    end
  end

  def self.handle_new(svc)
    Log.info { "NEW service (#{svc.name}) #{svc.args.join(" ")}" }
    @@services[svc.name] = svc
  end

  def self.handle_modified(existing_svc, svc)
    Log.info { "MODIFIED service (#{svc.name}) #{svc.args.join(" ")}" }
    @@services[svc.name] = svc
  end

  def self.handle_deleted(svc)
    Log.info { "DELETED service (#{svc.name}) #{svc.args.join(" ")}" }
    @@services.delete(svc.name)
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

    Signal::HUP.trap do
      ServiceManager.watch
    end

    loop do
      ServiceManager.watch
      sleep 60.seconds
    end
  end
end
