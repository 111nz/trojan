#!/bin/bash
if [[ $(id -u) != 0 ]]; then
    echo 请root用户运行这个脚本
    exit 1
fi
#######设置信息颜色############
ERROR="31m"      # Error message
SUCCESS="32m"    # Success message
WARNING="33m"   # Warning message
INFO="93m"     # Info message
LINK="95m"     # Share Link Message
#############################

blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
bred(){
    echo -e "\033[31m\033[01m\033[05m$1\033[0m"
}
byellow(){
    echo -e "\033[33m\033[01m\033[05m$1\033[0m"
}

sd="https://github.com/pymumu/smartdns/releases/download/Release30/smartdns.1.2020.02.25-2212.x86_64-debian-all.deb"

bbrplusFile="https://github.com/111nz/trojan/blob/master/bbrplus"

####################################
colorEcho(){
    COLOR=$1
    echo -e "\033[${COLOR}${@:2}\033[0m"
}
#########域名解析验证###################
isresolved(){
    if [ $# = 2 ]
    then
        myip=$2
    else
        myip=`curl --silent http://dynamicdns.park-your-domain.com/getip`
    fi
    ips=(`nslookup $1 1.1.1.1 | grep -v 1.1.1.1 | grep Address | cut -d " " -f 2`)
    for ip in "${ips[@]}"
    do
        if [ $ip == $myip ]
        then
            return 0
        else
            continue
        fi
    done
    return 1
}
###############安装输入选项################
userinput(){
green  " ============================================================================"
yellow " 请输入域名(每个域名每周只能使用5次，安装失败也算次数，可以换不同的域名解决）"
green  " ============================================================================"
read domain
  if [[ -z "$domain" ]]; then
    green  " =========================================================================================="
	yellow " 域名不能为空，请重新输入(每个域名每周只能使用5次，安装失败也算次数，可以换不同的域名解决）"
	green  " =========================================================================================="
    read domain
  fi
green  " ========================================="
yellow " 请输入密码(这个是配置trojan的密码，牢记）"
green  " ========================================="
read passwordd
  if [[ -z "$passwordd" ]]; then
	green  " ======================================================="
	yellow " 密码不能为空，请重新输入(这个是配置trojan的密码，牢记）"
	green  " ========================================================"
    read passwordd
  fi
}
###############linux系统检查####################
osdist(){

set -e
 if cat /etc/*release | grep ^NAME | grep Debian; then
    green  " ======================="
	yellow " linux系统检查通过"
	green  " ======================="
    dist=debian
 else
    green  " ======================="
	red " 只能在debian10以上安装"
	green  " ======================="
    exit 1;
 fi
}
###############更新系统list################
updatesystem(){
if [[ $dist = debian ]]; then

    if [[ $(lsb_release -cs) == buster ]]; then
cat << EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian buster main contrib non-free
deb-src http://deb.debian.org/debian buster main contrib non-free
deb http://security.debian.org/debian-security buster/updates main contrib
deb-src http://security.debian.org/debian-security buster/updates main contrib
EOF
    elif [[ $(lsb_release -cs) == stretch ]]; then
      cat << EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian/ stretch main
deb-src http://deb.debian.org/debian/ stretch main
deb http://security.debian.org/ stretch/updates main
deb-src http://security.debian.org/ stretch/updates main
deb http://deb.debian.org/debian/ stretch-updates main
deb-src http://deb.debian.org/debian/ stretch-updates main
EOF
    fi
export DEBIAN_FRONTEND=noninteractive
apt-get upgrade -q -y
apt-get update
apt-get install iptables-persistent -q -y > /dev/null

if [ -x "$(command -v curl)" ]; then
  apt-get install sudo socat xz-utils apt-transport-https gnupg gnupg2 dnsutils lsb-release python-pil unzip resolvconf -qq -y
else
  apt-get install sudo curl socat xz-utils apt-transport-https gnupg gnupg2 dnsutils lsb-release python-pil unzip resolvconf -qq -y
fi

source /etc/profile
else
  clear
  green  " =============="
	red " 依赖包更新出错"
	green  " =============="
  exit 1;
 fi
 
}

#########打开防火墙端口########################
openfirewall(){
  iptables -I INPUT -p tcp -m tcp --dport 443 -j ACCEPT
  iptables -I INPUT -p tcp -m tcp --dport 80 -j ACCEPT
  iptables -I OUTPUT -j ACCEPT
}

###从官方源开始安装trojan####
installtrojan-gfw(){
  bash -c "$(wget -O- https://raw.githubusercontent.com/trojan-gfw/trojan-quickstart/master/trojan-quickstart.sh)"
}

##########安装nginx################
nginxapt(){
  wget https://nginx.org/keys/nginx_signing.key -q
  apt-key add nginx_signing.key
  rm -rf nginx_signing.key
  touch /etc/apt/sources.list.d/nginx.list
  cat > '/etc/apt/sources.list.d/nginx.list' << EOF
deb https://nginx.org/packages/mainline/debian/ $(lsb_release -cs) nginx
deb-src https://nginx.org/packages/mainline/debian/ $(lsb_release -cs) nginx
EOF
  apt-get remove nginx-common -qq -y
  apt-get update -qq
  apt-get install nginx -q -y
}

############安装nginx########################
installnginx(){
  if [[ $dist = debian ]]; then
    nginxapt
 else
  clear
    green  " =============="
	red " 安装nginx错误"
	green  " =============="
    exit 1;
 fi
}
#############安装acme#####################
installacme(){
  curl -s https://get.acme.sh | sh
  sudo ~/.acme.sh/acme.sh --upgrade --auto-upgrade > /dev/null
  rm -rf /etc/trojan/
  mkdir /etc/trojan/
}
##################################################
issuecert(){
  rm -rf /etc/nginx/sites-enabled/*
  rm -rf /etc/nginx/sites-available/*
  rm -rf /etc/nginx/conf.d/*
  touch /etc/nginx/conf.d/default.conf
    cat > '/etc/nginx/conf.d/default.conf' << EOF
server {
    listen       80;
    server_name  $domain;
    #charset koi8-r;
    #access_log  /var/log/nginx/host.access.log  main;
    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }
    #error_page  404              /404.html;
    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
    # proxy the PHP scripts to Apache listening on 127.0.0.1:80
    #
    #location ~ \.php$ {
    #    proxy_pass   http://127.0.0.1;
    #}
    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #
    #location ~ \.php$ {
    #    root           html;
    #    fastcgi_pass   127.0.0.1:9000;
    #    fastcgi_index  index.php;
    #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
    #    include        fastcgi_params;
    #}
    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    #
    #location ~ /\.ht {
    #    deny  all;
    #}
}
EOF
  wget https://github.com/111nz/trojan/blob/master/web.zip
    unzip web.zip
  rm -rf /usr/share/nginx/html/*
  mv ./index.html /usr/share/nginx/html/
  rm -rf web.zip
  systemctl start nginx
  sudo ~/.acme.sh/acme.sh --issue --nginx -d $domain -k ec-256 --force --log
}
##################################################
renewcert(){
  sudo ~/.acme.sh/acme.sh --issue --nginx -d $domain -k ec-256 --force --log
}
##################################################
installcert(){
  sudo ~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/trojan/trojan.crt --keypath /etc/trojan/trojan.key --ecc
}
##################################################
installkey(){
  chmod +r /etc/trojan/trojan.key
}
##################################################
changepasswd(){
  openssl dhparam -out /etc/trojan/trojan.pem 2048
  cat > '/usr/local/etc/trojan/config.json' << EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "passwordd"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "/etc/trojan/trojan.crt",
        "key": "/etc/trojan/trojan.key",
        "key_password": "",
        "cipher": "TLS_AES_128_GCM_SHA256",
	"cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": true,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "prefer_ipv4": true,
        "no_delay": true,
        "keep_alive": true,
        "fast_open": true,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": ""
    }
}
EOF
  sed  -i "s/passwordd/$passwordd/g" /usr/local/etc/trojan/config.json
}
########在nginx配置trojan##############
nginxtrojan(){
rm -rf /etc/nginx/sites-available/*
rm -rf /etc/nginx/sites-enabled/*
rm -rf /etc/nginx/conf.d/*
touch /etc/nginx/conf.d/trojan.conf
  cat > '/etc/nginx/conf.d/trojan.conf' << EOF
server {
  listen 127.0.0.1:80;
    server_name $domain;
    location / {
      root /usr/share/nginx/html/;
        index index.html;
        }
  add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
}
server {
    listen 80;
    listen [::]:80;
    server_name $domain;
    return 301 https://$domain;
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
}
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 444;
}
EOF
nginx -s reload
}

##########启动trojan&nginx###############
autostart(){
  systemctl start trojan
  systemctl enable nginx
  systemctl enable trojan
}

############安装smartdns#################
install_sdns(){
wget --no-check-certificate -O ~/smartdns.deb $sd
dpkg -i ~/smartdns.deb

cat << EOF > /etc/smartdns/smartdns.conf
bind 127.0.0.1:53
bind :5533
cache-size 20480
#prefetch-domain yes
rr-ttl 86400
#rr-ttl-min 3600
#rr-ttl-max 604800
log-level info
log-file /var/log/smartdns.log
log-size 128k
log-num 2
force-AAAA-SOA yes
# default port is 853
server-tls 8.8.8.8
server-tls 8.8.4.4
server-tls 1.0.0.1
# default port is 443
server-https https://dns.google/dns-query
server-https https://cloudflare-dns.com/dns-query
EOF

echo "" > /run/smartdns.pid
cat << EOF > /lib/systemd/system/smartdns.service
[Unit]
Description=Smart DNS server
After=network-online.target
Before=nss-lookup.target
Wants=network-online.target
[Service]
Type=forking
PIDFile=/run/smartdns.pid
EnvironmentFile=/etc/default/smartdns
ExecStart=/usr/sbin/smartdns $SMART_DNS_OPTS
KillMode=process
Restart=always
RestartSec=2s
LimitNPROC=1000000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
rm -rf ~/smartdns.deb

echo "nameserver 127.0.0.1" > '/etc/resolv.conf'

systemctl daemon-reload > /dev/null 2>&1
systemctl enable smartdns > /dev/null 2>&1
systemctl restart smartdns > /dev/null 2>&1
}


#安装BBRplus内核
installbbrplus(){
    kernel_version="4.14.129-bbrplus"
	if [[ $dist = debian ]]; then
		mkdir bbrplus
        cd bbrplus
		wget -N --no-check-certificate ${bbrplusFile}/linux-headers-${kernel_version}.deb
		wget -N --no-check-certificate ${bbrplusFile}/linux-image-${kernel_version}.deb
		dpkg -i linux-headers-${kernel_version}.deb
		dpkg -i linux-image-${kernel_version}.deb
		cd .. && rm -rf bbrplus
	fi
	detele_kernel
    #remove_all
	optimizing_system

}




#卸载全部加速
remove_all(){
	rm -rf bbrmod
	sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    sed -i '/fs.file-max/d' /etc/sysctl.conf
	sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
	sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
	sed -i '/net.core.rmem_default/d' /etc/sysctl.conf
	sed -i '/net.core.wmem_default/d' /etc/sysctl.conf
	sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
	sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_tw_recycle/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_keepalive_time/d' /etc/sysctl.conf
	sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_mtu_probing/d' /etc/sysctl.conf
	sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
	sed -i '/fs.inotify.max_user_instances/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
	sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
	sed -i '/net.ipv4.route.gc_timeout/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_synack_retries/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_syn_retries/d' /etc/sysctl.conf
	sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
	sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_timestamps/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_orphans/d' /etc/sysctl.conf
	#clear
	#echo -e "${Info}:清除加速完成。"
	sleep 1s
}

#优化系统配置
optimizing_system(){
    
echo "fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_orphans = 32768
# forward ipv4
net.ipv4.ip_forward = 1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbrplus">>/etc/sysctl.conf
sysctl -p
/usr/sbin/update-grub
}


#删除多余内核
detele_kernel(){
	if [[ $dist = debian ]]; then
		deb_total=`dpkg -l | grep linux-image | awk '{print $2}' | grep -v "${kernel_version}" | wc -l`
		if [ "${deb_total}" > "1" ]; then
			echo -e "检测到 ${deb_total} 个其余内核，开始卸载..."
			for((integer = 1; integer <= ${deb_total}; integer++)); do
				deb_del=`dpkg -l|grep linux-image | awk '{print $2}' | grep -v "${kernel_version}" | head -${integer}`
				echo -e "开始卸载 ${deb_del} 内核..."
				apt-get purge -y ${deb_del}
				echo -e "卸载 ${deb_del} 内核卸载完成，继续..."
			done
			echo -e "内核卸载完毕，继续..."
		else
			echo -e " 检测到 内核 数量不正确，请检查 !" && exit 1
		fi
	fi
}


##########卸载Trojan-Gfw##########
removetrojan(){
  systemctl stop trojan
  systemctl disable trojan
  rm -rf /usr/local/etc/trojan/*
  rm -rf /etc/trojan/*
  rm -rf /etc/systemd/system/trojan.service
  rm -rf ~/.acme.sh/$domain
}

###########卸载Nginx dnsmasq and acme###############
removenginx(){
  systemctl stop nginx
  systemctl disable nginx
  apt purge nginx -p -y
  apt purge dnsmasq -p -y
  rm -rf /etc/apt/sources.list.d/nginx.list
  sudo ~/.acme.sh/acme.sh --uninstall
}
##########检查更新trojan############
checkupdate(){
  cd
  wget https://install.direct/go.sh -q
  sudo bash go.sh --check
  rm go.sh
  bash -c "$(wget -O- https://raw.githubusercontent.com/trojan-gfw/trojan-quickstart/master/trojan-quickstart.sh)"
}

function dd_instl(){
    bash <(wget --no-check-certificate -qO- 'https://github.com/111nz/trojan/blob/master/dd') -d 10 -v 64 -p 'miyue' -a
}
function tg_pxy(){
    bash <(wget --no-check-certificate -qO- https://github.com/111nz/trojan/blob/master/tg_pxy)
}

DELAY=3 

while true; do
  clear
  green " ========================================================================"
  green " 简介：debian一键安装trojan"
  green " 系统：>=debian9"
  green " Youtube：米月"
  green " 电报群：https://t.me/mi_yue"
  green " Youtube频道地址：https://t.im/n21o"
  green " 版本：20200304v3"
  green " ========================================================================"
  echo
  green  " 1. 一键安装trojan（包含bbr plus）"
  #green  " 2. 一键更新trojan"
  #red    " 3. 一键卸载trojan"
  green  " 4. 一键tg代理（端口默认9443）"
  green  " 5. 一键DD（安装全新debian10，只有阿里云需要，其它vps慎用）（登录密码：miyue）"
  yellow " 0. 退出安装trojan"
  echo

  read -p "请输入数字[0-5] > "

  if [[ $REPLY =~ ^[0-5]$ ]]; then
    case $REPLY in
      1)
        userinput
        osdist
        updatesystem
    green  " ==============="
		yellow " 开始安装smartdns"
		green  " ==============="
        install_sdns
        #dnsmasq
        #if isresolved $domain
        #then
        #:
        #else 
		#green  " =========================="
		#red " 请检查域名和vps的地址是否一致"
		#green  " =========================="
        #exit -1
        #fi
        openfirewall
        green  " =============="
		yellow " 开始安装trojan"
		green  " =============="
        installtrojan-gfw
        green  " ============="
		yellow " 开始安装nginx"
		green  " ============="
        installnginx
        green  " ============"
		yellow " 开始安装acme"
		green  " ============"
        installacme
        green  " ============"
		yellow " 开始申请证书"
		green  " ============"
        issuecert
        green  " ==================="
		yellow " 开始nginx配置trojan"
		green  " ==================="
        nginxtrojan
        green  " ================"
		yellow " 开始安装安装证书"
		green  " ================"
        installcert
        installkey
        green  " =============="
		yellow " 开始配置trojan"
		green  " =============="
        changepasswd
        green  " ======================"
		yellow " 设置自启动trojan nginx"
		green  " ======================"
        autostart
		yellow " 开始安装bbr plus"
		green  " ==========================="
        #tcp-bbr
        installbbrplus
		green " ========================================================================="
		green " 简介：debian一键安装trojan"
		green " 系统：debian10"
		green " Youtube：米月"
		green " 电报群：https://t.me/mi_yue"
		green " Youtube频道地址：https://t.im/n21o"
		green " ========================================================================="
		green " Trojan已安装完成，复制下面的信息，在OP里进行配置"
		red   " 服务器地址：$domain"
		red   " 服务器端口：443"
		red   " 服务器密码：$passwordd"
    red   " TLS1.3加密：TLS_AES_128_GCM_SHA256"
		red   " 忘记密码修改文件：/usr/local/etc/trojan/config.json"
		green " ========================================================================="
        break
        ;;
      2)
        checkupdate
        break
        ;;
      3)
        removetrojan
        removenginx
        green  " =============="
	  	  yellow " 卸载trojan完成"
		    green  " =============="
        break
        ;; 
        4)
        tg_pxy
        break
        ;; 
      5)
        dd_instl
        break
        ;;       
      0)
        break
        ;;
    esac
  else
    green  " ============================"
	red " 输入的数字不正确，请重新输入"
	green  " ============================"
    sleep $DELAY
  fi
done
