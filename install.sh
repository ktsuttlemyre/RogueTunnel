#!/bin/bash
set -ex
#original script 
# https://github.com/cloudflare/argo-tunnel-examples/blob/master/terraform-zerotrust-ssh-http-gcp/server.tpl
#Resources:
#cloudflare
# https://fariszr.com/en/cloudflared-docker-setup/
# https://omar2cloud.github.io/cloudflare/cloudflared/cloudflare/
#self hosted
#https://github.com/fractalnetworksco/selfhosted-gateway
#list of tunnel software
# https://github.com/anderspitman/awesome-tunneling

# Script to install Cloudflare Tunnel and Docker resources
echo "Some of the commands will need sudo access. Please grant sudo use."
#do a sudo command to get the password out of the way
sudo echo "Thank you" || exit 1

as="${1:-cloudflare_service}" # cloudflare_service, cloudflare_docker, selfhosted_gateway
cert="${2:-~/.cloudflared/cert.json}"
config="${3:-~/.cloudflared/config.yml}"

settings_dir=/etc/cloudflare/


#################################################
cert_json=$(cat << "EOF"
{
  "AccountTag"   : "${AccountTag}",
  "TunnelID"     : "${TunnelID}",
  "TunnelName"   : "${TunnelName}",
  "TunnelSecret" : "${TunnelSecret}"
}
EOF
)

#################################################
config_yml=$(cat << "EOF"
tunnel: ${TunnelID}
#this will be handled for you
credentials-file: /etc/cloudflared/cert.json
logfile: /var/log/cloudflared.log
loglevel: info

ingress:
	- hostname: ${domain}
		service: http://localhost:8080
	- hostname: ssh.${domain}
		service: ssh://localhost:22
  	- hostname: vnc.${domain}
		service: vnc://localhost:5900
	- hostname: "*"
		path: "^/tunnelcheck$"
		service: http_status:200
	- hostname: "*"
		service: hello-world
EOF
)


# cloudflared configuration
cd
if [ "$as" == 'cloudflare_service' ]; then
  #install
  if ! command -v cloudflared &> /dev/null; then
	#https://pimylifeup.com/raspberry-pi-cloudflare-tunnel/
	sudo apt update && apt upgrade
	sudo apt install curl lsb-release
	VERSION=$(lsb_release -cs)
	#find codename with only bash
	# . /etc/os-release
	# read _ UBUNTU_VERSION_NAME <<< "$VERSION"
	# VERSION="$(echo "$VERSION" | cut -f 1 -d " ")"
	 # VERSION="$(echo "$a" | tr '[:upper:]' '[:lower:]')"
	curl -L https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-archive-keyring.gpg >/dev/null
	echo "deb [signed-by=/usr/share/keyrings/cloudflare-archive-keyring.gpg] https://pkg.cloudflare.com/cloudflared $VERSION main" | sudo tee  /etc/apt/sources.list.d/cloudflared.list
	sudo apt update
	sudo apt install -y cloudflared
  fi
  
  # A local user directory is first created before we can install the tunnel as a system service 
  mkdir -p /etc/cloudflared/

  # Another herefile is used to dynamically populate the JSON credentials file
  if [ -f "$cert" ]; then
  	mv "$cert" ${settings_dir}cert.json
  else
  	echo "${cert_json}" > ${settings_dir}cert.json 
  fi
  cert=${settings_dir}cert.json
  
  # Same concept with the Ingress Rules the tunnel will use 
  if [ -f "$config" ]; then
    mv "$config" ${settings_dir}config.yml
  else
    echo "${config_yml}" > ${settings_dir}config.yml
  fi
  config=${settings_dir}config.yml
  # Now we install the tunnel as a systemd service 
  sudo cloudflared --config $config service install
    
  # start the tunnel 
  sudo systemctl enable cloudflared
  sudo systemctl start cloudflared
elif [ "$as" == 'cloudflare_docker' ]; then
  # Retrieveing the docker repository for this OS
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
  # The OS is updated and docker is installed
  sudo apt update -y && sudo apt upgrade -y
  sudo apt install docker docker-compose -y 
elif [ "$as" == 'selfhosted_docker' ]; then

else
  echo "unknown value for how you wish to install"
  exit 1
fi
echo "Complete!"
