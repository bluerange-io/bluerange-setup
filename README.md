# BlueRange setup

Required companion files for setting up BlueRange on various platforms. Detailed installation instructions can be found [here](https://www.bluerange.io/docs/bluerange-installguide/index.html).

## Requirements

### Platforms

BlueRange runs dockerized and needs the current versions of Docker and Docker Compose.

### Databases

BlueRange has been verified to work with:

- PostgreSQL 14.0 or newer
- MariaDB 10.11 LTS or a newer LTS version
- MongoDB 7

## Installation

There is a convenience (bluerange-compose.sh)[./bluerange-compose.sh] script added, as a wrapper for docker compose that sets up the needed environment in a deterministic way.

Notice, the [bluerange-compose.sh](bluerange-compose.sh) script can be used just like `docker-compose`:

```sh
# start all-in-one BlueRange software stack
$ ./bluerange-compose.sh up -d

# display all logs with follow
$ ./bluerange-compose.sh logs -f

# tear down all-in-one BlueRange software stack
$ ./bluerange-compose.sh down
```

The volumes `mysql`, `postgresql` and `mongodb` are set up in order not to lose data stored when the nodes are rebuild.

### Hosted service ports

The following ports are available on the hosting machine:

- 80: HTTP of `traefik`, auto redirect to HTTPS enabled
- 443: HTTPS of `traefik` and MQTT over WebSockets
- 1883: MQTT using TCP of `mosquitto`, bound to docker host only
- 3306: MySQL service of `database`, bound to docker host only
- 5432: PostgreSQL service of `postgresql`, bound to docker host only
- 8080: BlueRange UI of `bluerange`, bound to docker host only
- 8099: Spring Actuators of `bluerange`, bound to docker host only
- 8883: MQTT using SSL of `mosquitto`
- 27017: MongoDB service of `mongodb`, bound to docker host only

Ports not required for operation but for diagnostics only are bound to the docker host only. All port mappings may be customized by overwriting them in the `server.env` file. The names of those custom port mappings can be looked up in [.env](.env) and are prefixed by `PORT_`.

### Required configuration

The compose scripts expect that the following file is provided:

- `server.env`: environment variable file containing the host machine name as registered in DNS and mail server configuration

The `server.env` file should look like this:

```env
HOST=my-machine.my-domain.me
SMTP_HOST=smtp-machine.my-domain.me
SMTP_PORT=25
SMTP_USERNAME=smtp-username
SMTP_PASSWORD=XXXXXXXX
```

### HTTPS certificate

The HTTPS certificate required may be generated using <https://letsencrypt.org/>. Please make sure to have a property DNS record set up for your workstation.

Certificates are obtained by the [Traefik](https://traefik.io/traefik/) container. To enable it, choose one of the supported challenges: `TLS-ALPN-01` `HTTP-01` or `DNS-01` and check the [detailed documentation](https://doc.traefik.io/traefik/https/acme/) for the needed parameter.

Add the traefik static config in the CLI syntax to the `docker-compose.override.yml` like:
```
services:
  traefik:
    command:
      - --certificatesresolvers.letsencrypt.acme.dnschallenge.provider=manual
      ### for testing purpose the let's encrypt stating environment can be activated
      # - --certificatesresolvers.letsencrypt.acme.caServer=https://acme-staging-v02.api.letsencrypt.org/directory
      ### any configuration from the docker-compose.yml can be overridden
      # - --log.level=DEBUG
```

### Optional configuration

For the SQL database, the `docker-compose.yml` contains both PostgreSQL (current recommendation) and MariaDB (legacy). To activate one or the other, [profiles](https://docs.docker.com/compose/profiles/) are used, which can be configured by setting `COMPOSE_PROFILES` in `server.env`.

Please see the [Migration Guide](MIGRATION.md) for switching from MariaDB to PostgreSQL.

Further customization should be done using the `docker-compose.override.yml` mechanism, see <https://docs.docker.com/compose/extends/>.

To customize the BlueRange server itself, use the [application.yml](application.yml).

### Getting Started

By default, the environment is set up automatically creating an organization named `IOT`. It is expected to enroll IoT things therein. To log on use username `admin` and password `${ORGA_ADMIN_PASSWORD}`.

From here, we'll recommend to follow the [Quick Start Guide](https://bluerange.io/docs/bluerange-manual/General/QuickStart.html) in our documentation.

## Backup and Restore

The script `bluerange-backup.sh` allows saving the database content and server configuration into a single file:

```sh
$ ./bluerange-backup.sh
...
* backup/bluerange-20210421_132111.tar.gz
```

The backup file can be uploaded to some permanent storage such as S3. The script is intended to run regularly using cron, for example.

The `bluerange-restore.sh` script allows restoring the installation given a fresh working copy:

```sh
$ ./bluerange-restore.sh backup/bluerange-20210421_132111.tar.gz
All existing BlueRange server data will be erased!
Are you sure to restore from bluerange-20210421_132111?
Type YES: YES
...
Backup bluerange-20210421_132111 restored.
* ./bluerange-compose.sh to start the server...
```

Finally start the server using `bluerange-compose.sh` once so that the system services are installed.

