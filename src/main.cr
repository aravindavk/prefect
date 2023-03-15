require "./service_manager"

Log.setup(:debug)

ServiceManager.run("./services")
