
# # tor config
#     if [ "$DEPLOY_ONION_SITE" = true ]; then
#         cat >>"$NGINX_CONF_PATH" <<EOL
#     # server listener for tor v3 onion endpoint
#     server {
#         listen 443 ssl http2;
#         listen [::]:443 ssl http2;
#         server_name ${ONION_ADDRESS};
#         #access_log /var/log/nginx/tor-www.log;
        
#         # administration not allowed over tor interface.
#         location /ghost { deny all; }
#         location / {
#             proxy_set_header X-Forwarded-For 1.1.1.1;
#             proxy_set_header X-Forwarded-Proto https;
#             proxy_set_header X-Real-IP 1.1.1.1;
#             proxy_set_header Host \$http_host;
#             proxy_pass http://tor-ghost:2368;
#         }
#     }
# EOL
#     fi
