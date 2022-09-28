





#     if [ "$DEPLOY_NEXTCLOUD" = true ]; then
#         cat >>"$NGINX_CONF_PATH" <<EOL
#     # TLS listener for ${NEXTCLOUD_FQDN}
#     server {
#         listen 443 ssl http2;
#         listen [::]:443 ssl http2;

#         ssl_certificate $CONTAINER_TLS_PATH/fullchain.pem;
#         ssl_certificate_key $CONTAINER_TLS_PATH/privkey.pem;
#         ssl_trusted_certificate $CONTAINER_TLS_PATH/fullchain.pem;

#         server_name ${NEXTCLOUD_FQDN};
        
#         location / {
#             proxy_headers_hash_max_size 512;
#             proxy_headers_hash_bucket_size 64;
#             proxy_set_header X-Real-IP \$remote_addr;
#             proxy_set_header Host \$host;
#             proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#             proxy_set_header X-Forwarded-Proto \$scheme;
#             proxy_set_header X-NginX-Proxy true;
            
#             proxy_pass http://nextcloud:80;
#         }
                    
#         # https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/reverse_proxy_configuration.html
#         location /.well-known/carddav {
#             return 301 \$scheme://\$host/remote.php/dav;
#         }

#         location /.well-known/caldav {
#             return 301 \$scheme://\$host/remote.php/dav;
#         }
#     }
# EOL

#     fi

