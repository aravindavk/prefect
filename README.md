# Prefect

Lightweight manager for running processes.

## Install

Run below command to download and install the `prefect` tool.

```
curl -fsSL https://github.com/aravinda/prefect/releases/latest/download/install.sh | sudo bash -x
```

## Usage

Start the Service manager service. 

```
prefect mgr --svc-dir=/home/ubuntu/services
```

### Add a new service

```
prefect add <name> <arg1> <arg2> ...
```

```
export PREFECT_DIR=/home/ubuntu/services
prefect add kadalu-mgr "/usr/sbin/kadalu mgr --port=3000" --auto-restart
```

Above command creates a service file under `SVC_DIR` (`$PREFECT_DIR/kadalu-mgr.json`). Also caches the content in memory.

### Delete a service

```
prefect delete kadalu-mgr
```

This deletes the service file.

### List the managed services

```
prefect status
```

### Send signal to a service

```
prefect signal <service-name> <signal>
prefect signal kadalu-mgr SIGHUP
```

### Restart the service

```
prefect restart <service-name>
```

Terminates the running service by looking at PID and then service manager will take care of starting it.

### Update the args or change the service

```
prefect update kadalu-mgr /usr/local/sbin/kadalu mgr --port=3001
```

This command updates the service file.

## How it works?

Service manager gets the list of service files exists in the `SVC_DIR` and starts all the services. It periodically watches the service files to identify the new services, modified services and deleted services. Send `SIGHUP` to trigger the reload of service files if the interval is not suitable.

- If in-memory service data is not available but service file exists, `NEW` service
- If in-memory service data is different from the service file content, `MODIFIED` service
- If in-memory service data is not available as file, `DELETED` service

On fresh start, all the services are identified as `NEW`

