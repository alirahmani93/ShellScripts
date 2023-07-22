# Sentry Self-hosted Service

In order to maintain a working Sentry installation, you should:

* Have enough CPU cores for Kafka
* Configure Redis
* Remove old Postgres data regularly
* Configure Nginx

## Kafka

According to <https://develop.sentry.dev/self-hosted/troubleshooting/>, this error is reported sometimes:

```bash
Exception: KafkaError{code=OFFSET_OUT_OF_RANGE,val=1,str="Broker: Offset out of range"}
```

To the best of my knowledge, if you dedicate enough CPU and RAM to the machine, this problem is solved.

## Redis

By default, Redis uses all the RAM it could allocate and there is no limit. Therefore, one should configure Redis to use a limited amount of RAM and prune keys once the limit has been reached.

To configure Redis either:

* Build a new docker image using this Dockerfile:
  * The Dockerfile:

    ```
    FROM redis:6.2.10-alpine
    COPY ./redis.conf /usr/local/etc/redis/redis.conf
    EXPOSE 6379
    CMD [ "redis-server", "/usr/local/etc/redis/redis.conf" ]
    ```
  * Insert the redis.conf using a volume based on this config:

    ```
    protected-mode noport 6379
    tcp-backlog 511timeout 0
    tcp-keepalive 300
    daemonize nopidfile /var/run/redis_6379.pidloglevel notice
    logfile ""
    databases 16
    always-show-logo no
    set-proc-title yes
    proc-title-template "{title} {listen-addr} {server-mode}"
    save 3600 1
    save 300 100
    save 60 10000
    stop-writes-on-bgsave-error yesrdbcompression yes
    rdbchecksum yesdbfilename dump.rdb
    rdb-del-sync-files no
    dir /datareplica-serve-stale-data yesreplica-read-only yes
    repl-diskless-sync norepl-diskless-sync-delay 5repl-diskless-load disabledrepl-disable-tcp-nodelay no
    replica-priority 100acllog-max-len 128
    maxmemory 3G
    maxmemory-policy allkeys-lfulazyfree-lazy-eviction no
    lazyfree-lazy-expire no
    lazyfree-lazy-server-del no
    replica-lazy-flush no
    lazyfree-lazy-user-del no
    lazyfree-lazy-user-flush no
    oom-score-adj nooom-score-adj-values 0 200 800
    disable-thp yesappendonly noappendfilename "appendonly.aof"appendfsync everysecno-appendfsync-on-rewrite no
    auto-aof-rewrite-percentage 100
    auto-aof-rewrite-min-size 64mbaof-load-truncated yes
    aof-use-rdb-preamble yeslua-time-limit 5000slowlog-log-slower-than 10000slowlog-max-len 128
    latency-monitor-threshold 0
    notify-keyspace-events ""
    hash-max-ziplist-entries 512
    hash-max-ziplist-value 64
    list-max-ziplist-size -2list-compress-depth 0
    set-max-intset-entries 512
    zset-max-ziplist-entries 128
    zset-max-ziplist-value 64hll-sparse-max-bytes 3000stream-node-max-bytes 4096
    stream-node-max-entries 100activerehashing yes
    client-output-buffer-limit normal 0 0 0
    client-output-buffer-limit replica 256mb 64mb 60
    client-output-buffer-limit pubsub 32mb 8mb 60
    hz 10dynamic-hz yesaof-rewrite-incremental-fsync yesrdb-save-incremental-fsync yes
    jemalloc-bg-thread yes
    ```
* Insert a **command directive** in your docker-compose.yml and specify the options:

  ```
    ...
    redis:
      <<: *restart_policy
      image: "redis:6.2.10-alpine"
      command: redis-server --loglevel warning  --maxmemory 3G --maxmemory-policy allkeys-lfu
      healthcheck:
        <<: *healthcheck_defaults
        test: redis-cli ping
      volumes:
        - "sentry_redis_2:/data"
        - ./redis_conf/redis.conf:/usr/local/etc/redis/redis.conf
      ...
  ```

# Postgres

Sentry stores its tracing data in Postgres and over time, it grows exponentially. Therefore, in order to make sure you do not run out of space, it is advised to run these cron jobs regularly. The commands along their schedules are  as follows:

```

10 2 */7 * * cd /home/medrick/Sentry_installation/self-hosted-23.2.0 && docker compose down && docker compose up -d postgres && sleep 10 && docker exec sentry-self-hosted-postgres-1 psql -U postgres -c "DELETE FROM public.nodestore_node WHERE "timestamp" < NOW() - INTERVAL '7';" && docker exec sentry-self-hosted-postgres-1 psql -U postgres -c "VACUUM FULL public.nodestore_node;" &&  docker compose down && docker compose up -d
0 15 */7 * * docker exec sentry-self-hosted-postgres-1 psql -U postgres -c "TRUNCATE TABLE repack.log_20249;"



```

The description of each cron job is as follows:


1. Here’s what happens in the **first** **cron job:**

   
   1. The docker stack is brought down.
   2. The Postgres inside the stack is brought up.
   3. The data older than 7 days ago s deleted from *public.nodestore_node* table;
   4. The *public.nodestore_node* table is vacuumed to make sure the space is freed and given back to the OS.
2. Here’s what happens in the **second** **cron job:**

   
   1. As it seemed that due to Sentry’s inner workings, the *repack.log_20249* table is filled with log data, it is truncated.


# Nginx

An Nginx instance is defined in Sentry’s docker-compose.yml. Note that the nginx.conf contains three important  

To make sure you have a working Nginx instance, use the configurations below.


1. The docker-compose service:

   ```
     nginx:
       <<: *restart_policy
       ports:
         - "$SENTRY_BIND:80/tcp"
         - 443:443
       image: "nginx:1.22.0-alpine"
       volumes:
         - type: bind
           read_only: true
           source: ./nginx
           target: /etc/nginx
         - sentry-nginx-cache:/var/cache/nginx
         - /var/lib/letsencrypt:/var/lib/letsencrypt:ro
         - /etc/letsencrypt:/etc/letsencrypt:ro
   
       depends_on:
         - web
         - relay
   ```
2. The nginx.conf:

   
   1. Do note the *upstreams:*

      ```
      # in nginx/nginx.conf
      
      user nginx;
      worker_processes auto;
      
      error_log /var/log/nginx/error.log warn;
      pid /var/run/nginx.pid;
      
      
      events {
              worker_connections 1024;
      }
      
      
      http {
              default_type application/octet-stream;
      
              log_format main '$remote_addr - $remote_user [$time_local] "$request" '
              '$status $body_bytes_sent "$http_referer" '
              '"$http_user_agent" "$http_x_forwarded_for"';
      
              access_log /var/log/nginx/access.log main;
      
              sendfile on;
              tcp_nopush on;
              tcp_nodelay on;
              reset_timedout_connection on;
      
              keepalive_timeout 75s;
      
              gzip off;
              server_tokens off;
      
              server_names_hash_bucket_size 64;
              types_hash_max_size 2048;
              types_hash_bucket_size 64;
              client_max_body_size 100m;
      
              proxy_http_version 1.1;
              proxy_redirect off;
              proxy_buffering off;
              proxy_next_upstream error timeout invalid_header http_502 http_503 non_idempotent;
              proxy_next_upstream_tries 2;
      
              # Remove the Connection header if the client sends it,
              # it could be "close" to close a keepalive connection
              proxy_set_header Connection '';
              proxy_set_header Host $host;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header X-Request-Id $request_id;
              proxy_read_timeout 30s;
              proxy_send_timeout 5s;
      
              # upstream 1
              upstream relay {
                      server relay:3000;
              }
              # upstream 2
              upstream sentry {
                      server web:9000;
              }
      
              server {
                      #listen 80;
                      listen 443 ssl;
                      ssl_certificate /etc/letsencrypt/live/sentry.medrick.info/fullchain.pem; # managed by Certbot
                      ssl_certificate_key /etc/letsencrypt/live/sentry.medrick.info/privkey.pem; # managed by Certbot
                      include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
                      ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
      
                      location /api/store/ {
                              proxy_pass http://relay;
                      }
                      location ~ ^/api/[1-9]\d*/ {
                              proxy_pass http://relay;
                      }
                      location / {
                              proxy_pass http://sentry;
                      }
              }
      
              server {
                     listen 80;
      
                      server_tokens off;
      
                      location /.well-known/acme-challenge/ {
                      root /var/www/certbot;
                      }
      
                      location / {
                      return 301 https://sentry.medrick.info$request_uri;
                      }
      
              }
      
      }
      ```


