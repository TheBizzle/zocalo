zócalo
===============

### Installation Instructions

#### Basics

  * If your machine doesn't already have it, you might need to [install libgmp](http://www.mathemagix.org/www/mmdoc/doc/html/external/gmp.en.html)
  * [Download Stack](https://docs.haskellstack.org/en/stable/README/)
  * Ensure that you have a working version of Postgres, by checking that `psql --version` and `pg_config --version` print version numbers; if not, your installation is probably broken, and fixing that will be addressed in the next section of this document

#### General Postgres Setup

  * [Download Postgresql](https://www.postgresql.org/download/)
    * This application has been tested on various versions of Postgres, 9 through 17, without issue, but there is the possibility of problems from version mismatches

  * If you get an error in the coming steps that says "Missing C library: pq" or about a missing `pg_config`, you need to get Postgres stuff onto your `PATH`
    * On Amazon Linux 2023, this can be achieved with `yum install libpq-devel --allowerasing`, in order to get a working version of `pg_config`
    * On Red Hat, this can be accomplished by installing `postgresql*-devel` through `yum`
    * On Ubuntu, it can be something more like `apt install postgresql-server-dev-9.6`

  * Ensure that the Postgres server is running by performing `ps aux | grep postgres` and looking for a `postgres` process; it's probably not running, so you can follow [these instructions](https://www.postgresql.org/docs/17/static/server-start.html) or the more-targeted guide below, where we manually set up basically everything
    * Setting up the `postgres` user
      * Make sure that the `postgres` user exists
      * Add `postgres` to any groups that you might want it to have
      * Use `passwd` to give the `postgres` user the password that you want
        * Launching the server as `postgres` on startup will be easiest with an empty password, so remove any password: `sudo passwd -d postgres`
          * If you're going to do this, first ensure in `/etc/ssh/sshd_config` that this user cannot log in over SSH by adding the line `DenyUsers postgres` and then restarting SSH with `sudo service ssh restart`
    * Make the data directory: `sudo mkdir -p /usr/local/pgsql/data`
    * Make a log directory: `sudo mkdir -p /usr/local/pgsql/log`
    * User `chmod`/`chown`/`chgrp` to set permissions on the data directory (probably make `postgres` the owner of the directory)
    * Initialize the datastore: `su postgres -c "initdb -D /usr/local/pgsql/data"`
    * Ensure that Postgres will launch at startup
      * This is a whole kerfuffle, involving adding this line to `/etc/rc.local`: `su postgres -c 'pg_ctl start -D /usr/local/pgsql/data/' -l /usr/local/pgsql/log/logfile.log`
      * The reason this turned into a kerfuffle on Amazon Linux 2023 was because `rc.local` was not set up as expected
        * Use `sudo systemctl status rc-local` to diagnose; values other than `Active: active` indicate error
    * Run whatever your startup script is (e.g. `/etc/rc.local`, if this Postgres-related stuff is all that's in it) to finally launch Postgres

#### zócalo-Specific Postgres Setup

  * Next, you'll need to initialize the Postgres database tables
    * Run `psql --username=postgres`
      * `CREATE DATABASE zocalo WITH ENCODING='UTF8' CONNECTION LIMIT=-1;`
      * `exit`

#### Configuring zócalo for Your Server

To configure the application for use on your machine, copy `conf/template.yaml` to `conf/actual.yaml` and open `conf/actual.yaml` in your text editor of choice.  The format is as follows:

  * Config YAML
    * **General**
      * **cryptography-secret**: A 32-bit base64-encoded stream of random digits; most easily obtained from running `head -c 32 /dev/urandom | base64`
    * **Database**
      * **host**: Usually `localhost`
      * **port**: Usually `5432`
      * **database-name**: Usually `zocalo` (from the `CREATE DATABASE` line above)
      * **username**: Your Postgres username (default: `postgres`)
      * **password**: Your Postgres password (default: ``)
    * **Mail**
      * **mailtrap-api-secret**: Your API token obtained from [Mailtrap](https://mailtrap.io/settings/api-tokens)
      * **sender-address**: What e-mail address you want the authentication e-mails to be sent from
      * **sender-name**: What name you want the authentication e-mails to show up with in people's inboxes

### Running

  * To run the server without HTTP, run `stack build && stack exec run-zocalo`

### Running with HTTPS

First, you need to get an HTTPS certificate.  The easiest way is to go through [CertBot/Let's Encrypt](https://certbot.eff.org/).

**Do not use the instructions in this paragraph, since they don't seem to work properly, even though they *should*.**  You can nominally run the web app with HTTPS enabled by filling in and running this command: `stack build && sudo /PATH/TO/STACK/stack exec --allow-different-user run-zocalo -- --port=80 --ssl-port=443 --ssl-cert=/PATH/TO/CERT/cert.pem --ssl-key=/PATH/TO/KEY/privkey.pem --ssl-address=0.0.0.0 --no-ssl-chain-cert` (your filenames for the key and cert may differ).

**However**, it seems that the Snap web server has a bug of some sort, where, after a period of time, it stops handling HTTPS requests.  As a result, it is recommended to simply run a different HTTP frontend server in front of zócalo.  Below are instructions for how to do that with Caddy.

#### HTTPS with Caddy

  * Install Caddy: `sudo snap install caddy`
  * Configure Caddy (see below for contents): `sudoedit /var/snap/caddy/common/Caddyfile`
  * Apply configuration changes: `caddy reload --config /var/snap/caddy/common/Caddyfile --adapter caddyfile`
  * Launch Caddy: `sudo snap start caddy.server`

The config text (assuming you want people accessing it via HTTPS without having to specify any port number):

```
:443 {
  tls PATH/TO/cert.pem PATH/TO/privkey.pem
  reverse_proxy 127.0.0.1:8000
}
```

(Fill in the two instances of `PATH/TO`.)

If you find that the Ubuntu/Snap-based installation of Caddy can't access your `.pem` files, that's likely because of Snap's security/sandboxing policies, and you may need to copy the `.pem` files to a Snap-accessible location (like somewhere in your home directory).

