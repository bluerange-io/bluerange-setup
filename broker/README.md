# Mosquitto MQTT Broker for BlueRange

This folder contains files necessary for on-premise installation of the Mosquitto MQTT broker supporting BlueRange.

## Prerequisites

For the MQTT broker you need:

- **fully-qualified name of host** to run the broker software on. The name MUST be registered with DNS. This is so that user and IoT devices can resolve the host.

- valid **HTTPS certificate and private key** matching that host/domain name so that client software has a chance establishing WSS connections to it.

- **ports 8883 and 9001 opened** in the firewall protecting the host.

Typically the IoT software and devices connect directly to the broker. Also, `BlueRange` itself MUST be able to resolve and reach the broker using the fully-qualified host name. Using the configuration file provided, the broker talks to `BlueRange` using plain HTTP on port 8080 directly for performance reasons.

## Linux

This is the recommended platform for MQTT broker installation supporting medium to high loads. In the optimal case the broker is being executed on a dedicated and stripped down machine providing no other services.

1. Please follow the instructions given at <https://mosquitto.org/download/> setting up Mosquitto for the Linux distribution in use.

2. Put the shared module [linux/auth-plug.so](linux/auth-plug.so) onto the `LDPATH` by copying it to a shared modules folder and change the file mode to allow execution.

3. Copy the [mosquitto.conf](mosquitto.conf) configuration file overwriting the default configuration file (typically located at `/etc/mosquitto`) and edit as required:

    - `auth_plugin` to the absolute pathname of the [linux/auth-plug.so](linux/auth-plug.so) copied in step 2.
    - `auth_opt_http_hostname` to name of machine where BlueRange is installed, when installed elsewhere.

4. Provide `server.key` and `server.pem` files next to the just edited configuration files containing the HTTPS certificate. These may be symbolic links to the `nginx` files when running on the same machine.

Notice, the plugin is precompiled to run on most 64-bit x86 Linux by M-Way Solutions GmbH. Do **NOT** operate the MQTT broker without authentication!

In the event of service startup failure you may want to alter the `logdest` configuration option to `stderr` (instead of `none`) for diagnostic purposes.

## Windows

This is the typical setup for single BlueRange on Windows node deployments where the broker gets installed onto the same machine. This setup is fine for smaller loads such as for the development of PoCs and in small enterprises.

1. Execute both [windows/vcredist_x86.exe](windows/vcredist_x86.exe) and then [windows/VC_redist.x86.exe](windows/VC_redist.x86.exe) for installation of required runtime libraries.

2. Copy the [windows](windows) folder to a folder of your choice, `C:\mosquitto`, for example.

3. Provide `server.key` and `server.pem` files containing the HTTPS certificate and put them into the mosquitto folder just copied.

4. Copy the [mosquitto.conf](mosquitto.conf) configuration file into the mosquitto folder and edit as required:

    - `auth_opt_http_hostname` to name of machine where BlueRange is installed, when installed elsewhere.
    - `keyfile`, `certfile` and `cafile` options must be changed to fully qualified paths for the service to work properly.

5. Run the `install_service.cmd` from inside the folder copied in step 2 from an elevated command prompt.

Please notice the `logdest` option must be set to `none` when starting as a Windows service as otherwise service startup will fail because no console is allocated for the service process to use.

## Mac OS

On-premise installation of the broker on MacOS is not supported. As a replacement, M-Way Solutions GmbH provides a suitable docker image upon request.

## BlueRange

For BlueRange to make use of the MQTT broker, add the following to the `application.yml` where `${MOSQUITTO_FQN_HOST}` MUST be replaced by the fully-qualified name of the MQTT broker as registered with DNS:

```yaml
mqtt:
  enabled: true
  server_uris: ssl://${MOSQUITTO_FQN_HOST}:8883,wss://${MOSQUITTO_FQN_HOST}:9001
```

Afterwards restart BlueRange and log in as server `admin`. Then navigate to `/system/portal` where the health indicator should display successful operation of the MQTT broker.
