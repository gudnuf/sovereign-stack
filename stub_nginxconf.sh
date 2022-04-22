#!/bin/bash

set -exu
cd "$(dirname "$0")"


if [ "$DEPLOY_ONION_SITE" = true ]; then
    if [ -z "$ONION_ADDRESS" ]; then
        echo "ERROR: ONION_ADDRESS is not defined."
        exit 1
    fi
fi


# here's the NGINX config. We support ghost and nextcloud.
NGINX_CONF_PATH="$SITE_PATH/nginx.conf"
echo "" > "$NGINX_CONF_PATH"
cat >>"$NGINX_CONF_PATH" <<EOL
events {
    worker_connections  1024;
}

http {
    client_max_body_size 100m;
    server_names_hash_bucket_size  128;
    server_tokens off;
    
    # this server block returns a 403 for all non-explicit host requests.
    #server {
    #    listen 80 default_server;
    #    return 403;
    #}

EOL


# ghost http to https redirects.
cat >>"$NGINX_CONF_PATH" <<EOL
    # http://${DOMAIN_NAME} redirect to https://${FQDN}
    server {
        listen 80;
        listen [::]:80;
        
        server_name ${DOMAIN_NAME};

        location / {
            # request MAY get another redirect at https://domain.tld for www.
            return 301 https://${DOMAIN_NAME}\$request_uri;
        }
    }
EOL

cat >>"$NGINX_CONF_PATH" <<EOL
    # http://${FQDN} redirect to https://${FQDN}
    server {
        listen 80;
        listen [::]:80;
        server_name ${FQDN};
        return 301 https://${FQDN}\$request_uri;
    }

EOL

# nextcloud http-to-https redirect
if [ "$DEPLOY_NEXTCLOUD" = true ]; then
cat >>"$NGINX_CONF_PATH" <<EOL
    # http://${NEXTCLOUD_FQDN} redirect to https://${NEXTCLOUD_FQDN}
    server {
        listen 80;
        listen [::]:80;
        server_name ${NEXTCLOUD_FQDN};
        return 301 https://${NEXTCLOUD_FQDN}\$request_uri;
    }

EOL
fi

# matrix http to https redirect.
if [ "$DEPLOY_MATRIX" = true ]; then
cat >>"$NGINX_CONF_PATH" <<EOL
    # http://${MATRIX_FQDN} redirect to https://${MATRIX_FQDN}
    server {
        listen 80;
        listen [::]:80;
        server_name ${MATRIX_FQDN};
        return 301 https://${MATRIX_FQDN}\$request_uri;
    }

EOL
fi

# gitea http to https redirect.
if [ "$DEPLOY_GITEA" = true ]; then
cat >>"$NGINX_CONF_PATH" <<EOL
    # http://${GITEA_FQDN} redirect to https://${GITEA_FQDN}
    server {
        listen 80;
        listen [::]:80;
        server_name ${GITEA_FQDN};
        return 301 https://${GITEA_FQDN}\$request_uri;
    }

EOL
fi

# TLS config for ghost.
cat >>"$NGINX_CONF_PATH" <<EOL
    # global TLS settings
    ssl_prefer_server_ciphers on;
    ssl_protocols TLSv1.3;
    ssl_certificate /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;  # about 40000 sessions
    ssl_session_tickets off;
    add_header Strict-Transport-Security "max-age=63072000" always;
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 198.54.117.10;


    # default server if hostname not specified.
    #server {
    #    listen 443 default_server;
    #    return 403;
    #}

    # map \$http_user_agent \$og_prefix {
    #     ~*(googlebot|twitterbot)/  /open-graph;
    # }

    # https://${DOMAIN_NAME} redirect to https://${FQDN}
    server {
        listen 443 ssl http2;
        listen [::]:443 ssl http2;
        
        server_name ${DOMAIN_NAME};

EOL
###########################################

if [ "$DEPLOY_NOSTR" = true ]; then
cat >>"$NGINX_CONF_PATH" <<EOL
        # We return a JSON object with name/pubkey mapping per NIP05.
        # https://www.reddit.com/r/nostr/comments/rrzk76/nip05_mapping_usernames_to_dns_domains_by_fiatjaf/sssss
        # TODO I'm not sure about the security of this Access-Control-Allow-Origin. Read up and restrict it if possible.
        location = /.well-known/nostr.json {
            add_header Content-Type application/json;
            add_header Access-Control-Allow-Origin *;
            return 200 '{ "names": { "_": "${NOSTR_ACCOUNT_PUBKEY}" } }';
        }
        
EOL
fi

cat >>"$NGINX_CONF_PATH" <<EOL
        # catch all; send request to ${FQDN}
        location / {
            return 301 https://${FQDN}\$request_uri;
        }
EOL
#####################################################
cat >>"$NGINX_CONF_PATH" <<EOL
    }

    #access_log /var/log/nginx/ghost-access.log;
    #error_log /var/log/nginx/ghost-error.log;

EOL

if [ "$ENABLE_NGINX_CACHING" = true ]; then
cat >>"$NGINX_CONF_PATH" <<EOL
    # main TLS listener; proxies requests to ghost service. NGINX configured to cache
    proxy_cache_path /tmp/nginx_ghost levels=1:2 keys_zone=ghostcache:600m max_size=100m inactive=24h;
EOL
fi

# the open server block for the HTTPS listener
cat >>"$NGINX_CONF_PATH" <<EOL
    server {
        listen 443 ssl http2;
        listen [::]:443 ssl http2;

        server_name ${FQDN};

EOL

# add the Onion-Location header if specifed.
if [ "$DEPLOY_ONION_SITE" = true ]; then
cat >>"$NGINX_CONF_PATH" <<EOL
        add_header Onion-Location https://${ONION_ADDRESS}\$request_uri;
        
EOL
fi

if [ "$ENABLE_NGINX_CACHING" = true ]; then
cat >>"$NGINX_CONF_PATH" <<EOL

        # No cache + keep cookies for admin and previews
        location ~ ^/(ghost/|p/|private/) {
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto  \$scheme;
            proxy_intercept_errors  on;
            proxy_pass http://ghost:2368;
        }
        
EOL
fi

# proxy config for ghost
cat >>"$NGINX_CONF_PATH" <<EOL
        # Set the crawler policy.
        location = /robots.txt { 
            add_header Content-Type text/plain;
            return 200 "User-Agent: *\\nAllow: /\\n";
        }

        location / {
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header Host \$http_host;

            proxy_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto  \$scheme;
            proxy_intercept_errors  on;
            proxy_pass http://ghost:2368;
EOL

if [ "$ENABLE_NGINX_CACHING" = true ]; then
cat >>"$NGINX_CONF_PATH" <<EOL
            # https://stanislas.blog/2019/08/ghost-nginx-cache/ for nginx caching instructions
            # Remove cookies which are useless for anonymous visitor and prevent caching
            proxy_ignore_headers Set-Cookie Cache-Control;
            proxy_hide_header Set-Cookie;

            # Add header for cache status (miss or hit)
            add_header X-Cache-Status \$upstream_cache_status;
            proxy_cache ghostcache;

            # Default TTL: 1 day
            proxy_cache_valid 5s;

            # Cache 404 pages for 1h
            proxy_cache_valid 404 1h;

            # use conditional GET requests to refresh the content from origin servers
            proxy_cache_revalidate on;
            proxy_buffering on;

            # Allows starting a background subrequest to update an expired cache item,
            # while a stale cached response is returned to the client.
            proxy_cache_background_update on;

            # Bypass cache for errors
            proxy_cache_use_stale error timeout invalid_header updating http_500 http_502 http_503 http_504;
   
EOL
fi

# this is the closing location / block for the ghost HTTPS segment
cat >>"$NGINX_CONF_PATH" <<EOL
        }

EOL

# TODO this MIGHT be part of the solution for Twitter Cards.
        # location /contents {
        #     resolver 127.0.0.11 ipv6=off valid=5m;
        #     proxy_set_header X-Real-IP \$remote_addr;
        #     proxy_set_header Host \$http_host;
        #     proxy_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
        #     proxy_set_header X-Forwarded-Proto  \$scheme;
        #     proxy_intercept_errors  on;
        #     proxy_pass http://ghost:2368\$og_prefix\$request_uri;
        # }

# setup delegation for matrix
if [ "$DEPLOY_MATRIX" = true ]; then
cat >>"$NGINX_CONF_PATH" <<EOL
        # Set up delegation for matrix: https://github.com/matrix-org/synapse/blob/develop/docs/delegate.md
        location /.well-known/matrix/server {
		    default_type application/json;
		    return 200 '{"m.server": "${MATRIX_FQDN}:8448"}';
	    }
EOL
fi

# this is the closing server block for the ghost HTTPS segment
cat >>"$NGINX_CONF_PATH" <<EOL
    
    }

EOL

# tor config
if [ "$DEPLOY_ONION_SITE" = true ]; then
cat >>"$NGINX_CONF_PATH" <<EOL
    # server listener for tor v3 onion endpoint
    server {
        listen 443 ssl http2;
        listen [::]:443 ssl http2;
        server_name ${ONION_ADDRESS};
        #access_log /var/log/nginx/tor-www.log;
        
        # administration not allowed over tor interface.
        location /ghost { deny all; }
        location / {
            proxy_set_header X-Forwarded-For 1.1.1.1;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header X-Real-IP 1.1.1.1;
            proxy_set_header Host \$http_host;
            proxy_pass http://tor-ghost:2368;
        }
    }
EOL
fi

if [ "$DEPLOY_NEXTCLOUD" = true ]; then
cat >>"$NGINX_CONF_PATH" <<EOL
    # TLS listener for ${NEXTCLOUD_FQDN}
    server {
        listen 443 ssl http2;
        listen [::]:443 ssl http2;
        server_name ${NEXTCLOUD_FQDN};
        
        location / {
            proxy_headers_hash_max_size 512;
            proxy_headers_hash_bucket_size 64;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header Host \$host;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-NginX-Proxy true;
            
            proxy_pass http://nextcloud:80;
        }
                    
        # https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/reverse_proxy_configuration.html
        location /.well-known/carddav {
            return 301 \$scheme://\$host/remote.php/dav;
        }

        location /.well-known/caldav {
            return 301 \$scheme://\$host/remote.php/dav;
        }
    }
EOL
fi

if [ "$DEPLOY_MATRIX" = true ]; then
cat >>"$NGINX_CONF_PATH" <<EOL
    # TLS listener for ${MATRIX_FQDN} (matrix)
    server {
        # matrix RESTful calls.
        listen 443 ssl http2;
        listen [::]:443 ssl http2;
        
        # for the federation port
        listen 8448 ssl http2 default_server;
        listen [::]:8448 ssl http2 default_server;

        server_name ${MATRIX_FQDN};
        
        location ~ ^(/_matrix|/_synapse/client) {
            proxy_pass http://matrix:8008;
            proxy_set_header X-Forwarded-For \$remote_addr;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header Host \$host;
            client_max_body_size 50M;
        }
    }
EOL
fi


if [ "$DEPLOY_GITEA" = true ]; then
cat >>"$NGINX_CONF_PATH" <<EOL
    # TLS listener for ${GITEA_FQDN}
    server {
        listen 443 ssl http2;
        listen [::]:443 ssl http2;
    
        server_name ${GITEA_FQDN};
        
        location / {
            proxy_headers_hash_max_size 512;
            proxy_headers_hash_bucket_size 64;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header Host \$host;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-NginX-Proxy true;
            
            proxy_pass http://gitea:3000;
        }
    }
EOL
fi

# add the closing brace.
cat >>"$NGINX_CONF_PATH" <<EOL
}
EOL