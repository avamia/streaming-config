# Guide

I've put together a simple guide on how to setup multiple endpoint streaming for free. This will rebroadcast your local stream to popular streaming sites like Facebook, Twitch, Youtube and others.

## Prerequisites
1. First thing make sure to have a server running. You can get cheap cloud machines running on AWS, Azure, Digital Ocean, etc.
2. Have the proper firewall rules setup for the RTMP protocol. The standard port for RTMP is 1935. Make sure you only accept incoming streams from your local IP address, not the entire world.
3. If you decide to save recordings on your server, make sure to have enough disk space, otherwise things will go wrong quickly when space runs out.

## Dependencies
Update the system

```
sudo apt update
```

Install local depedencies

```
sudo apt install git build-essential libpcre3 libpcre3-dev libssl-dev nginx libnginx-mod-rtmp ffmpeg zlib1g-dev stunnel4  net-tools
```

Download latest NGINX source code, available at <https://nginx.org/download/>

```
cd /usr/src
sudo wget https://nginx.org/download/nginx-1.19.7.tar.gz
```

Clone the RTMP module for NGINX

```
git clone https://github.com/arut/nginx-rtmp-module
```

Build the NGINX binary with the RTMP module added. Make sure to include all of the following flags, otherwise NGINX won't run as you'd expect.

```
cd nginx-1.19.7
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

sudo make
sudo make install
```

Clean things up

```
cd ../
sudo rm -rf nginx-rtmp-module
sudo rm nginx-1.19
```

## Setting up NGINX Config File
Here we'll configure NGINX to work with the various stremaing sources.

Note: You can find the complete config file in this repo, nginx.conf.

Go to the config directory and remove the default config file.
```
cd /etc/nginx
sudo rm nginx.conf
```

Next, we'll create a new config file and the appropriate settings.

```
sudo vim nginx.conf
```

The top section includes standard settings to set number of connection workers and specify where the NGINX pid file is located.

```bash
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
	worker_connections 1024;
}
```

The main part of the RTMP settings is under the rtmp directive. Make sure to include the access_log setting so you can troubleshoot later on.
```
rtmp {
	access_log /var/log/nginx/rtmp_access.log;
}
```

The server block is where we configure which port to listen on and how big the file size is for each video segment.

The larger the chunk size, the less strain this will have on your CPU. However, keep in mind the bigger this is, you'll have bigger dropped segements of video chunks if there's poor network connectivity. I've settled on 4096 as a good in-between.

```
rtmp {
	access_log /var/log/nginx/rtmp_access.log;
	
	server {
		listen 1935;
		chunk_size 4096;
	}
}
```

The application directive within the server block defines RTMP applications that you can push and pull from for video streams.

In this example, live means that this is a live stream. Recording is turned off, all meta data on this RTMP stream is copied to the client, and we'll notify the clients when initiating the stream.
```
rtmp {
	access_log /var/log/nginx/rtmp_access.log;
	
	server {
		listen 1935;
		chunk_size 4096;

		application live {
			live on;
			record off;
			meta copy;
			publish_notify on;
		}
	}
}
```

To be able to view the stream over HTTP(s), use the HLS directive. This isn't necessary for pushing to other streaming platforms, however, it gives you another way of pushing your video streaming to your own website with a video player.

Make sure to create the `/mnt/hls` directory before running NGINX with HLS turned on. You can place the HLS segments in any directory you'd like.

Fragment directs NGINX what the duration should be for each video chunk that's temporarily saved. Playlist length is number of video files before deleting old ones.

```
rtmp {
	access_log /var/log/nginx/rtmp_access.log;
	
	server {
		listen 1935;
		chunk_size 4096;

		application live {
			live on;
			record off;
			meta copy;
			publish_notify on;

			# Turn on HLS
			hls on;
			hls_path /mnt/hls/;
			hls_fragment 2s;
			hls_playlist_length 60;
		}
	}
}
```

With the NGINX RTMP module, you can rebroadcast a stream to another source. You can do this directly, or use an intermediary with the localhost loopback device.

Here, the live application is pushing the same incoming stream to the twitch, facebook and youtube rtmp applications. These will need to be defined as a seperate application. Another benefit of segmenting these out into seperate applications, is that you could downscale the video stream to a smaller format, or using ffmepg, convert the video into another format specifically for that endpoint.

```
rtmp {
	access_log /var/log/nginx/rtmp_access.log;
	
	server {
		listen 1935;
		chunk_size 4096;

		application live {
			live on;
			record off;
			meta copy;
			publish_notify on;

			# Turn on HLS
			hls on;
			hls_path /mnt/hls/;
			hls_fragment 2s;
			hls_playlist_length 60;

			# Push to other sources
			push rtmp://localhost/twitch;
			push rtmp://localhost/youtube;
			push rtmp://localhost/facebook;
		}
	}
}
```

Putting everything together, we have the following RTMP directive defined.

A few things to note, the allow publish directive is telling NGINX that only the defined network / address is able to publish to this source. Since the address is `127.0.0.1`, ie the loopback device or localhost network, only the server itself can publish to this source. The subsequent deny publish all turns off the ability for other sources to publish to this application.

With Twitch and Youtube, they use the standard RTMP protocol, so you can push directly to those endpoints. Make sure to replace the private streaming key here, and don't share this with anyone!

Facebook, however, uses RTMPS. At the time of writing this guide, the NGINX RTMP module does not support rtmps. This is easily solved with stunnel, which essentially relays the encrypted video stream to the facebook endpoint. 

Keep in mind, since NGINX is already listening on port 1935 on localhost, you'll need to use another port for this intermediary stream. Here, I'm using 19350. Again, remember to copy over Facebook's private stream key.

```
rtmp {
	access_log /var/log/nginx/rtmp_access.log;
	
	server {
		listen 1935;
		chunk_size 4096;

		application live {
			live on;
			record off;
			meta copy;
			publish_notify on;

			# Turn on HLS
			hls on;
			hls_path /mnt/hls/;
			hls_fragment 2s;
			hls_playlist_length 60;

			# Push to other sources
			push rtmp://localhost/twitch;
			push rtmp://localhost/youtube;
			push rtmp://localhost/facebook;
		}

		application twitch {
			live on;
			record off;
			meta copy;
			allow publish 127.0.0.1;
			deny publish all;

			push rtmp://live.twitch.tv/app/{TWITCH_STREAM_KEY};
		}

		application youtube {
			live on;
			record off;
			meta copy;
			allow publish 127.0.0.1;
			deny publish all;

			push rtmp://a.rtmp.youtube.com/live2/{YOUTUBE_STREAM_KEY};
		}

		application facebook {
			live on;
			record off;
			meta copy;
			allow publish 127.0.0.1;
			deny publish all;

			push rtmp://127.0.0.1:19350/rtmp/{FACEBOOK_STREAM_KEY};
		}
	}
}
```

Next, we'll work on defining the web server hosting the html file to view the video stream over http.

The http directive tells nginx to run a http web server. There's a few standard directives to include here, and you can read about them in more detail at this [blog post](https://thoughts.t37.net/nginx-optimization-understanding-sendfile-tcp-nodelay-and-tcp-nopush-c55cdd276765).  

```
http {
	sendfile on;
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 65;
	types_hash_max_size 2048;

	include /etc/nginx/mime.types;
}
```

The server block, similar to the rtmp directive let's us specify what port NGINX should listen to, the server name and many other settings NGINX give you. We'll use port 80 for HTTP. At some point, I'll update this guide to include HTTPS for encrypted web traffic.

Make sure to update the server_name directive to the domain you expect to route your traffic to. You can use _ to accept all connections.

```
http {
	sendfile on;
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 65;
	types_hash_max_size 2048;

	include /etc/nginx/mime.types;

	server {
		listen 80;
		listen [::]:80;
		server_name example.com;
	}
}
```

Next, we'll define where the index.html file will load from. I've seperated this from the hls directory, as this was causing issues with the content type being sent back to the browser. `/var/www/html` is a common location for hosting websites. The location directive is what defines a path for the webserver. The root directive tells nginx where the root of the application is, and the index tells nginx which file to server for loading that path.

```
http {
	sendfile on;
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 65;
	types_hash_max_size 2048;

	include /etc/nginx/mime.types;

	server {
		listen 80;
		listen [::]:80;
		server_name example.com;

		location / {
		    root   /var/www/html;
		    index  index.html index.htm;
		}
	}
}
```

To load the HLS video segments, we'll need to define where to load those files. Remember that directory we defined earlier for the chunk file sizes? We'll point the webserver to load those files here.

A few things to understand. Types defines what type of video files are being served. The root directive tells nginx where to find the video files. Don't use `root /mnt/hls` as this will cause an error. Sine you are specifying the location /hls, NGINX will append this to the `root /mnt` path.

Make sure not to cache any video files, otherwise the browser will try to load old video segments. 

We need to specify a few options with Cross Domain Origin settings or CORS. This allows the video to be loaded from various domains. If you only want your video stream accessible by the domain loading the html file, turn off the CORS settings.

All-in-all, this the entire http server directive that will serve the html file for the video stream.

```
http {
	sendfile on;
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 65;
	types_hash_max_size 2048;

	include /etc/nginx/mime.types;

	server {
		listen 80;
		listen [::]:80;
		server_name example.com;

		location / {
		    root   /var/www/html;
		    index  index.html index.htm;
		}

		location /hls {
		    # Serve HLS fragments
		    types {
		        application/vnd.apple.mpegurl m3u8;
		        video/mp2t ts;
		    }
		    root /mnt;
		    add_header Cache-Control no-cache;

		    # CORS setup
		    add_header 'Access-Control-Allow-Origin' '*' always;
		    add_header 'Access-Control-Expose-Headers' 'Content-Length';

		    # Allow CORS preflight requests
		    if ($request_method = 'OPTIONS') {
		        add_header 'Access-Control-Allow-Origin' '*';
		        add_header 'Access-Control-Max-Age' 1728000;
		        add_header 'Content-Type' 'text/plain charset=UTF-8';
		        add_header 'Content-Length' 0;
		        return 204;
		    }
		}
	}
}
```

## Setting up Stunnel

Stunnel is used to route the un-encrypted RTMP traffic from nginx to encrypted traffic for Facebook's RTMPS endpoint. Since the stunnel package was installed near the beginning of this tutorial, all that's needed is to create a config file.

```
sudo vim /etc/stunnel/stunnel.conf
```

Copy over the config file from the gitrepo. Accept denotes the listen address and port. This is localhost and 19350 for the relayed traffic from nginx. Connect is the endpoint to push the stream to. Double check on the facebook producer panel to ensure this is the correct endpoint.

```
[fb-live]
client = yes
accept = 127.0.0.1:19350
connect = live-api-s.facebook.com:443
verifyChain = no
```

## Restarting the Servers

Once NGINX and Stunnel conifg files are properly copied over and updated with your private stream keys, you'll need to restart these servers so they are using the most up to date settings.

```
sudo service nginx restart
```

If you get an error from nginx such as  `unknown directive "rtmp" in /etc/nginx/nginx.conf` this means you are using a compiled version of NGINX without the rtmp module. 

I struggled with this as I had first tried using the nginx-full and rtmp packages directly from the apt repo. For whatever reason this didn't work, so I then tried compiling from source as indicated above, but I didn't include the proper flags that tell the make file where to place the binaries.

This by default installs nginx at `/usr/local/nginx/sbin/nginx` which makes it difficult to use the systemctl and service init files to run nginx smoothly. Double check and make sure you are configuring things with the apporpriate flags.

To restart stunnel, run the following command

```
sudo service stunnel4 start
```

If you get an error, it may be because you ran the service with the 1935 port defined, which would already be in use by NGINX.

## Verifying your Connection
After restaring nginx and stunnel, you can double check that the process are running, ie:

```
ps aux | grep nginx
ps aux | grep stunnel4
```

You should see nginx master and worker process running. Likewise, the stunnel4 binnary should be running with the config file that was defined in `/etc/stunnel/stunnel.conf`.

Further, to double check the correct ports are setup, run

```
sudo netstat -atpn
```

Here, you should see localhost:19350 for the stunnel server listening for connections at 19350, as well as 0.0.0.0:1935 for the nginx server listening for the RTMP stream at 1935.

You should also see 0.0.0.0:80, which is the nginx web server listening on port 80 for incoming requests to serve the index.html file. If you are running https, then 0.0.0.0:443 would be running as well.

## Streaming Live

After you've verified NGINX and Stunnel are running, you can start by running your stream from the application of your choice. I use OBS.

With OBS, go to Settings, then Stream. Choose custom for the service option. You'll want to specify the following Server with the external ip address from your hosting provider. Make sure to include the `/live` section as this was specified in the nginx.conf file under the application directive. Use whatever application name you are using here.

```
rtmp://server-ip-goes-here/live
```

For the Stream Key, you can use whatever value you want here. Since you are pushing the stream key to the server and no one else, it's not as sensitive as the stream keys from the other platforms. From a vulenarability perspective, if you leave port 1935 open to the entire world, then anyone could push video streams to your server, and it would be re-broadcasted to other platforms.

This is why it's important to limit port 1935 to the ip address of your local network, so only you can push to this endpoint.

Further, with the stream key that you use in OBS, this will be the same value that's used to get the HLS video data in the html file that's loaded for the video player.

If all is working properly, you'll be able to broadcast your live stream to several endpoints at the same time, as well as load the stream directly on a webpage. Pretty cool, huh!?