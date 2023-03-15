# Services manager

Lightweight manager for running processes.

## Install

## Usage

Start the Service manager service. 

```
service-manager mgr --svc-dir=/var/lib/kadalu/services
```

### Add a new service

```
service-manager add <name> <arg1> <arg2> ...
```

```
export SVC_DIR=/var/lib/kadalu/services
service-manager add kadalu-mgr kadalu mgr --port=3000
```

Above command creates a service file under `SVC_DIR` (`$SVC_DIR/kadalu-mgr.json`). Also caches the content in memory.

### Delete a service

```
service-manager delete kadalu-mgr
```

This deletes the service file.

### List the managed services

```
service-manager list
service-manager list --status
```

### Send signal to a service

```
service-manager signal <service-name> <signal>
service-manager signal kadalu-mgr SIGHUP
```

### Restart the service

```
service-manager restart <service-name>
```

Terminates the running service by looking at PID and then service manager will take care of starting it.

### Update the args or change the service

```
service-manager update kadalu-mgr kadalu mgr --port=3001
```

This command updates the service file.

## How it works?

Service manager gets the list of service files exists in the `SVC_DIR` and starts all the services. It periodically watches the service files to identify the new services, modified services and deleted services. Send `SIGHUP` to trigger the reload of service files if the interval is not suitable.

- If in-memory service data is not available but service file exists, `NEW` service
- If in-memory service data is different from the service file content, `MODIFIED` service
- If in-memory service data is not available as file, `DELETED` service

On fresh start, all the services are identified as `NEW`

