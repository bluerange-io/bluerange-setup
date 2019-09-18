# BlueRange in Docker

This docker compose script starts one BlueRange instance, MySQL and MongoDB databases, an nginx frontend proxy, a Mosquitto MQTT broker and a Node Red instance.

The volumes `mysql` and `mongodb` are set up in order not to lose data stored when the nodes are rebuild.

## Hosted service ports

The following ports are available on the hosting machine:

- 443: HTTPS of `nginx`
- 1881: Node Red HTTP service of `nodered`
- 1884: MQTT using TCP of `mosquitto`
- 3307: MySQL service of `database`
- 8081: BlueRange UI of `bluerange`
- 8100: Spring Actuators of `bluerange`
- 8884: MQTT using SSL of `mosquitto`
- 9002: MQTT over WebSockets of `mosquitto`
- 27018: MongoDB service of `mongodb`

Except of nginx HTTPS, these ports are all off-by-one from their respective defaults to avoid collisions with locally running services on the hosting machine.

## Required configuration

As a minimum before starting the compose you need to provide a the following 3 files:

- server.env: environment variable file containing the host machine name as registered in DNS and mail server configuration
- server.pem: certificate chain used for HTTPS which must match the host machine name registered with DNS
- server.key: private key for issuing the HTTPS certificate

The server.env file should look like this:

```env
HOST=my-machine.my-domain.me
SMTP_HOST=smtp-machine.my-domain.me
SMTP_PORT=25
SMTP_USERNAME=smtp-username
SMTP_PASSWORD=XXXXXXXX
```

The HTTPS certificate required may be generated using <https://letsencrypt.org/>. Please make sure to have a property DNS record set up for your workstation.

## Optional configuration

The [docker-compose.yml](docker-compose.yml) contains commented sections for running `nginx` in debug mode and for mounting a custom `mosquitto.conf` file, see <https://hub.docker.com/r/relution/relution-mosquitto>.

## Appliance configuration

So far the configuration above offers a fully functioning BlueRange server environment for testing and/or development purposes. In production scenarios logging and update servers are required as well.

Typically a logging server such as an ELK installation exists in the IT infrastructure hosting BlueRange already and shall be reused. As update server mostly the publically available cloud service is used.

### Elasticsearch logging server

 In case an additional Elasticsearch logging server must be set up, the file [docker-compose.elasticsearch.yml](docker-compose.elasticsearch.yml) contains the relevant additional services required, based on [Open Distro for Elasticsearch](https://opendistro.github.io/for-elasticsearch/).

To use it firstly convert the server.key to PKCS#8 format required by Elasticsearch (see <https://stackoverflow.com/questions/6559272/algid-parse-error-not-a-sequence>) and then start both the compositions:

```sh
# convert server.key to PKCS#8
$ openssl pkcs8 -topk8 -inform PEM -in server.key -out server.pk8 -nocrypt

# start both compose files
$ docker-compose -f docker-compose.yml -f docker-compose.elasticsearch.yml up -d
```

In order to let the mesh gateway devices know about the custom logging server, a configuration policy must be applied in the platform.

### Mender update server

Likewise the file [docker-compose.mender.yml](docker-compose.mender.yml) contains the setup required to start a dedicated Mender update server:

```sh
# start BlueRange IoT server and Mender update server
$ docker-compose -f docker-compose.yml -f docker-compose.mender.yml up -d
```

Once started the update server is available via HTTPS at port 444, i.e. <https://my-machine.my-domain.me:444>. In order to log into the server an initial user account must be created explicitly:

```sh
# create user admin@my-machine.my-domain.me in Mender
$ docker-compose exec -T mender-useradm useradm create-user --username=admin@my-machine.my-domain.me --password=admin123
```

In order to let the mesh gateway devices know about the custom update server, a configuration policy must be applied in the platform.

### BlueRange software stack

Finally to help getting started with a fully self-administered on-premise setup including all of BlueRange, ElasticSearch and Mender the entire software stack can be started at once:

```sh
# convert server.key to PKCS#8
$ openssl pkcs8 -topk8 -inform PEM -in server.key -out server.pk8 -nocrypt

# start all-in-one BlueRange software stack
$ ./bluerange-compose.sh

Starting bluerange_database_1  ... done
Starting bluerange_bluerange_1 ... done
Starting bluerange_mosquitto_1 ... done
Starting bluerange_nodered_1   ... done
Starting bluerange_nginx_1     ... done
...

mender-useradm$ useradm create-user --username=admin@my-machine.my-domain.me --password=admin123
4f091170-da1a-11e9-aaef-0800200c9a66

    BlueRange: https://my-machine.my-domain.me:443  (admin / admin123)
       Mender: https://my-machine.my-domain.me:444  (admin@my-machine.my-domain.me / admin123)
       Kibana: https://my-machine.my-domain.me:5602 (admin / admin)
ElasticSearch: https://my-machine.my-domain.me:9201 (admin / admin)
```

Notice, the [bluerange-compose.sh](bluerange-compose.sh) script can be used just like `docker-compose`:

```sh
# display all logs with follow
$ ./bluerange-compose.sh logs -f

# stop all-in-one BlueRange software stack
$ ./bluerange-compose.sh down
```

Further customization should be done using the `docker-compose.override.yml` mechanism, see <https://docs.docker.com/compose/extends/>.

## Beacons and the Mesh Gateway

By default, the environment is set up automatically creating an organization named `IOT`. It is expected to enroll IoT things therein. To log on use username `admin` and password `iot12345`.

Start by creating a Site, enrolling a Mesh Gateway and positioning some Beacons... or have a look at the manual at <https://www.bluerange.io/docs/master/iot_development.html> to get going.

## Node RED and MQTT

The Node RED instance can be accessed through nginx at <https://my-machine.my-domain.me/nodered> specifying username `iot` and password `mway1234` as credentials. Additional users can be added using the command `htpasswd htpasswd ${username}`. On Cent OS 7 the tool can be installed using `yum install httpd-tools`. For further information see [Restricting Access with HTTP Basic Authentication](https://docs.nginx.com/nginx/admin-guide/security-controls/configuring-http-basic-authentication/).

**At the time of writing only the System/Organization Administrator accounts are allowed to send messages to MQTT.** Other users connecting to MQTT using access tokens are granted read-only access to their respective organization only. Any attempt violating security restrictions may cause immediate disconnection!

### To get credentials for connecting to Node RED to the `mosquitto` broker...

The values required for authentication are specific to each installation. It is not possible to write them down here, but this is how to obtain the information required:

1. Log on to BlueRange <https://my-machine.my-domain.me> with username `admin` and password `iot12345`.
2. Go to `Settings/Organization` and then the details of `IOT`. Now, in the browser address bar there is the UUID of the IOT Organization displayed. Write down the *iot-organization-uuid*.
3. Go to `Settings/Users` and then the details of `admin` of the `IOT` organization. Now, the address bar shows the UUID of the IOT Administrator. Write it down as *iot-administrator-uuid*.
4. In the menu please go to `IOT Administrator/Profile` and then tab `Access Tokens`.
5. Create an Access Token giving it a name at your discretion, ideally `nodered`. Write down your *iot-access-token-secret*.

Information required for setting up the connection are:

- server: `mosquitto`
- port: `1883`
- username: `Token-`*iot-administrator-uuid*`-nodered`
- password: *iot-access-token-secret*
- topic: `rltn-iot/`*iot-organization-uuid*`/#`

### An example flow that can be imported...

```javascript
[
    {
        "id": "38d59f86.19688",
        "type": "mqtt in",
        "z": "e648d23d.3bddc",
        "name": "",
        "topic": "rltn-iot/${iot-organization-uuid}/#",
        "qos": "0",
        "broker": "21e63dd2.d444f2",
        "x": 260,
        "y": 60,
        "wires": [
            [
                "c1f6d91e.5e1768"
            ]
        ]
    },
    {
        "id": "c1f6d91e.5e1768",
        "type": "debug",
        "z": "e648d23d.3bddc",
        "name": "",
        "active": true,
        "tosidebar": true,
        "console": false,
        "tostatus": false,
        "complete": "payload",
        "x": 590,
        "y": 60,
        "wires": []
    },
    {
        "id": "21e63dd2.d444f2",
        "type": "mqtt-broker",
        "z": "",
        "name": "mosquitto",
        "broker": "mosquitto",
        "port": "1883",
        "clientid": "",
        "usetls": false,
        "compatmode": true,
        "keepalive": "60",
        "cleansession": true,
        "willTopic": "",
        "willQos": "0",
        "willPayload": "",
        "birthTopic": "",
        "birthQos": "0",
        "birthPayload": "",
        "username": "Token-${iot administrator uuid}-nodered",
        "password": "${iot-access-token-secret}"
    }
]
```

Make sure to replace the `${iot-organization-uuid}`, `${iot administrator uuid}` and `${iot-access-token-secret}`. Notice, alternatively you may connect to `my-machine.my-domain.me`, port `8884` with `usetls`.

### Connecting `MQTT.fx` for sending arbitrary messages...

To connect [MQTT.fx](http://mqttfx.jensd.de/) to act as System Administrator to `mosquitto` please obtain credentials as:

1. Log on to BlueRange <https://my-machine.my-domain.me> with username `admin` and password `admin123`.
2. Go to `Settings/Users` and then the details of `admin` of the `SYSTEM` organization. Now, the address bar shows the UUID of the IOT Administrator. Write it down as *system-administrator-uuid*.
3. In the menu please go to `(?)/Web API`.
4. Open path `users` and operation `POST /gofer/security/rest/users/{userUuid}/accessTokens`.
5. Press `Try it out`.
6. Enter the *system-administrator-uuid* value for `userUuid` path parameter.
7. Enter the JSON `{"name": "MQTT.fx"}` as `accessToken` body parameter.
8. Click `Execute` exactly **once**.
9. Write down the `token` value of the response JSON body as *access-token-secret*.
10. Create an Access Token giving it a name at your discretion, ideally `nodered`. Write down your *system-access-token-secret*.

Information required for setting up the connection are:

- server: `my-machine.my-domain.me`
- port: `8884`
- username: `Token-`*system-administrator-uuid*`-nodered`
- password: *system-access-token-secret*

You need to enable SSL/TLS security.

When publishing messages keep in mind that Node RED is subscribed to `rltn-iot/`*iot-organization-uuid*`/#` so that only messages below this topic path are delivered to it.
