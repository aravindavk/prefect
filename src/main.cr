require "option_parser"

require "./prefect"

Log.setup(:info)

subcommand = ""
svc_dir = ""
auto_restart = false
pos_args = [] of String

parser = OptionParser.new do |parser|
  parser.banner = "Usage: prefect [subcommand] [arguments]"
  parser.on("mgr", "Start the service manager") do
    subcommand = "mgr"
    parser.banner = "Usage: prefect mgr [arguments]"
    parser.on("-d PATH", "--svc-dir=PATH", "Directory to store service files, status and pid files") { |path| svc_dir = path }
  end

  parser.on("add", "Add a new service") do
    subcommand = "add"
    parser.banner = "Usage: prefect add SVC_NAME COMMAND [arguments]"
    parser.on("--auto-restart", "Auto restart a service on failure") { auto_restart = true }
  end

  parser.on("update", "Update a service") do
    subcommand = "update"
    parser.banner = "Usage: prefect update SVC_NAME COMMAND [arguments]"
    parser.on("--auto-restart", "Auto restart a service on failure") { auto_restart = true }
  end

  parser.on("delete", "Delete a service") do
    subcommand = "delete"
    parser.banner = "Usage: prefect delete SVC_NAME"
  end

  parser.on("restart", "Restart a service") do
    subcommand = "restart"
    parser.banner = "Usage: prefect restart SVC_NAME"
  end

  parser.on("signal", "Send signal to a service") do
    subcommand = "signal"
    parser.banner = "Usage: prefect signal SVC_NAME COMMAND SIGNAL"
  end

  parser.on("status", "Status of the services") do
    subcommand = "status"
    parser.banner = "Usage: prefect status [SVC_NAME]"
  end

  parser.on("--version", "Show version information") do
    puts "TODO: Show version"
    exit
  end

  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
  parser.invalid_option do |flag|
  end
  parser.unknown_args { |args, _| pos_args = args }
end

parser.parse

def print_status(data)
  data.each do |key, value|
    printf("%20s: %s\n", key, value ? "Up" : "Down")
  end
end

def validate_pos_args(parser, args, num)
  if args.size < num
    STDERR.puts "Invalid arguments"
    STDERR.puts parser
    exit 1
  end
end

Prefect.svc_dir = ENV.fetch("SVC_DIR", "")

case subcommand
when "mgr"
  Prefect.run(svc_dir)
when "add"
  validate_pos_args(parser, pos_args, 2)
  args = pos_args[1].split(" ")
  Prefect.add_service(
    pos_args[0],
    args[0],
    args.size > 1 ? args[1..] : [] of String,
    auto_restart
  )
when "update"
  validate_pos_args(parser, pos_args, 2)
  args = pos_args[1].split(" ")
  Prefect.update_service(
    pos_args[0],
    args[0],
    args.size > 1 ? args[1..] : [] of String,
    auto_restart
  )
when "delete"
  validate_pos_args(parser, pos_args, 1)
  Prefect.delete_service(pos_args[0])
when "restart"
  validate_pos_args(parser, pos_args, 1)
  Prefect.restart_service(pos_args[0])
when "signal"
  validate_pos_args(parser, pos_args, 2)
  Prefect.signal_service(pos_args[0], pos_args[1].to_i)
when "status"
  data = Prefect.status_of_services
  print_status data
end
