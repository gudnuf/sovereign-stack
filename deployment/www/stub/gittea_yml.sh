



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
