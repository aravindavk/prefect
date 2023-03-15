require "./service_manager"

module Prefect
  extend self

  class_property svc_dir = ""

  class ServiceError < Exception
  end

  def validate_svc_dir
    if @@svc_dir == ""
      service_error "Prefect.svc_dir is not set"
    end
  end

  def service_error(msg)
    raise ServiceError.new msg
  end

  def svc_file(name)
    "#{@@svc_dir}/#{name}.json"
  end

  def save_service_file(name, path, args, auto_restart)
    svc = ServiceManager::Service.new name
    svc.auto_restart = auto_restart
    svc.path = path
    svc.args = args
    File.write(svc_file(name), svc.to_json)
  end

  def run(svc_dir)
    ServiceManager.run(svc_dir)
  end

  def add_service(name, path, args, auto_restart = false)
    validate_svc_dir
    svc_file = svc_file(name)

    if File.exists?(svc_file)
      service_error "Service already exists"
    end

    save_service_file(name, path, args, auto_restart)
    send_signal
  end

  def update_service(name, path, args, auto_restart = false)
    validate_svc_dir
    svc_file = svc_file(name)

    handle_service_not_exists(svc_file)

    save_service_file(name, path, args, auto_restart)
    send_signal
  end

  def handle_service_not_exists(svc_file)
    unless File.exists?(svc_file)
      service_error "Service doesn't exists"
    end
  end

  def delete_service(name)
    validate_svc_dir
    svc_file = svc_file(name)

    handle_service_not_exists(svc_file)

    File.delete svc_file
    send_signal
  end

  def signal_service(name, signal)
    validate_svc_dir
    svc_file = svc_file(name)
    handle_service_not_exists(svc_file)
    svc = ServiceManager::Service.from_json(File.read(svc_file))
    svc.restart = false
    svc.signal = signal.to_i
    File.write(svc_file, svc.to_json)
    send_signal
  end

  def restart_service(name)
    validate_svc_dir
    svc_file = svc_file(name)

    handle_service_not_exists(svc_file)

    svc = ServiceManager::Service.from_json(File.read(svc_file))
    svc.restart = true
    svc.signal = 0
    File.write(svc_file, svc.to_json)
    send_signal
  end

  def send_signal
    pid_file = "#{@@svc_dir}/pid"
    return unless File.exists?(pid_file)

    pid = File.read(pid_file).to_i
    if Process.exists?(pid) && File.read("/proc/#{pid}/cmdline") != ""
      Process.signal(Signal::HUP, pid)
    end
  end

  def status_of_services
    validate_svc_dir
    status_file = "#{@@svc_dir}/status"
    File.delete status_file
    send_signal
    # TODO: Exit after a few retries
    loop do
      if File.exists?(status_file)
        return Hash(String, Bool).from_json(File.read(status_file))
      end
      sleep 1.seconds
    end
  end
end
