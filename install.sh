## Install Dependencies

# Update server
sudo apt update

# Install other depedencies
sudo apt install build-essential libpcre3 libpcre3-dev libssl-dev nginx libnginx-mod-rtmp ffmpeg zlib1g-dev stunnel4 -y

## Download NGINX Source
## Get latest nginx version https://nginx.org/download/

cd /usr/src
sudo wget https://nginx.org/download/nginx-1.19.7.tar.gz
git clone https://github.com/arut/nginx-rtmp-module

sudo rm -rf nginx-1.19.7.tar.gz
cd nginx-1.19.7

## build from source
./configure --prefix=/usr/share/nginx \
            --sbin-path=/usr/sbin/nginx \
            --modules-path=/usr/lib/nginx/modules \
            --conf-path=/etc/nginx/nginx.conf \
            --error-log-path=/var/log/nginx/error.log \
            --http-log-path=/var/log/nginx/access.log \
            --pid-path=/run/nginx.pid \
            --lock-path=/var/lock/nginx.lock \
            --user=www-data \
            --group=www-data \
            --http-client-body-temp-path=/var/lib/nginx/body \
            --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
            --http-proxy-temp-path=/var/lib/nginx/proxy \
            --http-scgi-temp-path=/var/lib/nginx/scgi \
            --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
            --with-compat \
            --with-file-aio \
            --with-threads \
            --with-http_addition_module \
            --with-http_auth_request_module \
            --with-http_dav_module \
            --with-http_flv_module \
            --with-http_gunzip_module \
            --with-http_gzip_static_module \
            --with-http_mp4_module \
            --with-http_random_index_module \
            --with-http_realip_module \
            --with-http_slice_module \
            --with-http_ssl_module \
            --with-http_sub_module \
            --with-http_stub_status_module \
            --with-http_v2_module \
            --with-http_secure_link_module \
            --add-module=../nginx-rtmp-module \
            --with-mail \
            --with-mail_ssl_module \
            --with-stream \
            --with-stream_realip_module \
            --with-stream_ssl_module \
            --with-stream_ssl_preread_module 
make
sudo make install

## Edit the nginx conf file with RTMP settings
sudo vim /etc/nginx/nginx.conf

## Edit the stunnel conf file for SSL based streaming for Facebook
sudo vim /etc/stunnel/stunnel.conf
