#!/bin/bash

set -eu
cd "$(dirname "$0")"


# here's the NGINX config. We support ghost and nextcloud.
NGINX_CONF_PATH="$PROJECT_PATH/nginx.conf"

# clear the existing nginx config.
echo "" > "$NGINX_CONF_PATH"

# iterate over all our domains and create the nginx config file.
iteration=0
echo "DOMAIN_LIST: $DOMAIN_LIST"

for DOMAIN_NAME in ${DOMAIN_LIST//,/ }; do
    export DOMAIN_NAME="$DOMAIN_NAME"
    export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"
    export CONTAINER_TLS_PATH="/etc/letsencrypt/${DOMAIN_NAME}/live/${DOMAIN_NAME}"
    
    # source the site path so we know what features it has.
    source ../../reset_env.sh
    source "$SITE_PATH/site_definition"
    source ../../domain_env.sh

    echo "Doing DOMAIN_NAME: $DOMAIN_NAME"
    if [ $iteration = 0 ]; then
        cat >>"$NGINX_CONF_PATH" <<EOL
events {
    worker_connections  1024;
}

http {
    client_max_body_size 100m;
    server_tokens off;
    
    # next two sets commands and connection_upgrade block come from https://docs.btcpayserver.org/FAQ/Deployment/#can-i-use-an-existing-nginx-server-as-a-reverse-proxy-with-ssl-termination
    # Needed to allow very long URLs to prevent issues while signing PSBTs
    server_names_hash_bucket_size   128;
    proxy_buffer_size               128k;
    proxy_buffers                   4 256k;
    proxy_busy_buffers_size         256k;
    client_header_buffer_size       500k;
    large_client_header_buffers     4 500k;
    http2_max_header_size           500k;

    # Needed websocket support (used by Ledger hardware wallets)
    map \$http_upgrade \$connection_upgrade {
        default upgrade;
        ''      close;
    }

    # return 403 for all non-explicit hostnames
    server {
       listen 80 default_server;
       return 301 https://${WWW_FQDN}\$request_uri;
    }

EOL
    fi

    # ghost http to https redirects.
    cat >>"$NGINX_CONF_PATH" <<EOL
    # http://${DOMAIN_NAME} redirect to https://${WWW_FQDN}
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
    # http://${WWW_FQDN} redirect to https://${WWW_FQDN}
    server {
        listen 80;
        listen [::]:80;
        server_name ${WWW_FQDN};
        return 301 https://${WWW_FQDN}\$request_uri;
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

    # REDIRECT FOR BTCPAY_USER_FQDN
    if [ "$VPS_HOSTING_TARGET" = lxd ]; then
        # gitea http to https redirect.
        if [ "$DEPLOY_BTCPAY_SERVER" = true ]; then
        
        cat >>"$NGINX_CONF_PATH" <<EOL
    # http://${BTCPAY_USER_FQDN} redirect to https://${BTCPAY_USER_FQDN}
    server {
        listen 80;
        listen [::]:80;
        server_name ${BTCPAY_USER_FQDN};
        return 301 https://${BTCPAY_USER_FQDN}\$request_uri;
    }

EOL

        fi
    fi
    
    
    if [ "$iteration" = 0 ]; then
        # TLS config for ghost.
        cat >>"$NGINX_CONF_PATH" <<EOL
    # global TLS settings
    ssl_prefer_server_ciphers on;
    ssl_protocols TLSv1.3;
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;  # about 40000 sessions
    ssl_session_tickets off;
    add_header Strict-Transport-Security "max-age=63072000" always;
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 198.54.117.10;
    # TODO change resolver to local DNS resolver, or inherit from system.


    # default server if hostname not specified.
    server {
        listen 443 default_server;

        ssl_certificate $CONTAINER_TLS_PATH/fullchain.pem;
        ssl_certificate_key $CONTAINER_TLS_PATH/privkey.pem;
        ssl_trusted_certificate $CONTAINER_TLS_PATH/fullchain.pem;

        return 403;
    }

    # maybe helps with Twitter cards.
    #map \$http_user_agent \$og_prefix {
    #    ~*(googlebot|twitterbot)/  /open-graph;
    #}
EOL
    fi

        cat >>"$NGINX_CONF_PATH" <<EOL
    # https://${DOMAIN_NAME} redirect to https://${WWW_FQDN}
    server {
        listen 443 ssl http2;
        listen [::]:443 ssl http2;

        ssl_certificate $CONTAINER_TLS_PATH/fullchain.pem;
        ssl_certificate_key $CONTAINER_TLS_PATH/privkey.pem;
        ssl_trusted_certificate $CONTAINER_TLS_PATH/fullchain.pem;
        
        server_name ${DOMAIN_NAME};

        # catch all; send request to ${WWW_FQDN}
        location / {
            return 301 https://${WWW_FQDN}\$request_uri;
        }

EOL


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


    # SERVER block for BTCPAY Server
    if [ "$VPS_HOSTING_TARGET" = lxd ]; then
        # gitea http to https redirect.
        if [ "$DEPLOY_BTCPAY_SERVER" = true ]; then
        
            cat >>"$NGINX_CONF_PATH" <<EOL
    # http://${BTCPAY_USER_FQDN} redirect to https://${BTCPAY_USER_FQDN}
    server {
        listen 443 ssl http2;
        ssl on;

        ssl_certificate $CONTAINER_TLS_PATH/fullchain.pem;
        ssl_certificate_key $CONTAINER_TLS_PATH/privkey.pem;
        ssl_trusted_certificate $CONTAINER_TLS_PATH/fullchain.pem;

        server_name ${BTCPAY_USER_FQDN};
    
        # Route everything to the real BTCPay server
        location / {
            # URL of BTCPay Server
            proxy_pass http://10.139.144.10:80;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

            # For websockets (used by Ledger hardware wallets)
            proxy_set_header Upgrade \$http_upgrade;
        }
    }

EOL

        fi
    fi



# the open server block for the HTTPS listener
    cat >>"$NGINX_CONF_PATH" <<EOL
    server {
        listen 443 ssl http2;
        listen [::]:443 ssl http2;

        ssl_certificate $CONTAINER_TLS_PATH/fullchain.pem;
        ssl_certificate_key $CONTAINER_TLS_PATH/privkey.pem;
        ssl_trusted_certificate $CONTAINER_TLS_PATH/fullchain.pem;

        server_name ${WWW_FQDN};
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
            proxy_pass http://ghost-${iteration}:2368;
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
            #set_from_accept_language \$lang en es;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header Host \$http_host;

            proxy_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto  \$scheme;
            proxy_intercept_errors  on;
            proxy_pass http://ghost-${iteration}:2368;
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
        #     proxy_pass http://ghost-${iteration}::2368\$og_prefix\$request_uri;
        # }

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

        ssl_certificate $CONTAINER_TLS_PATH/fullchain.pem;
        ssl_certificate_key $CONTAINER_TLS_PATH/privkey.pem;
        ssl_trusted_certificate $CONTAINER_TLS_PATH/fullchain.pem;

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

    iteration=$((iteration+1))
done

# add the closing brace.
cat >>"$NGINX_CONF_PATH" <<EOL
}
EOL
