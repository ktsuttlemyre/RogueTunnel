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

os='' # linux,mac,windows,etc
as="${1:-cloudflare_service}" # cloudflare_service, cloudflare_docker, selfhosted_gateway
cert="${2}"
config="${3}"


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
credentials-file: /etc/cloudflared/cert.json
logfile: /var/log/cloudflared.log
loglevel: info

ingress:
	- hostname: ${web_zone}
		service: http://localhost:8080
	- hostname: ssh.${web_zone}
		service: ssh://localhost:22
	- hostname: "*"
		path: "^/_healthcheck$"
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
  mkdir -p ~/.cloudflared
  # Another herefile is used to dynamically populate the JSON credentials file 
  echo "${cert_json}" > ~/.cloudflared/cert.json 
  # Same concept with the Ingress Rules the tunnel will use 
  echo "${config_yml}" > ~/.cloudflared/config.yml

  
  # Now we install the tunnel as a systemd service 
  sudo cloudflared service install
  # The credentials file does not get copied over so we'll do that manually 
  sudo cp -via ~/.cloudflared/cert.json /etc/cloudflared/
  # start the tunnel 
  sudo service cloudflared start
elif [ "$as" == 'cloudflare_docker' ]; then
  # Retrieveing the docker repository for this OS
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
  # The OS is updated and docker is installed
  sudo apt update -y && sudo apt upgrade -y
  sudo apt install docker docker-compose -y 
else 
  echo "unknown value for how you wish to install"
  exit 1
fi
echo "Complete!"
