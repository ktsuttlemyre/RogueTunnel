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
as="${1:-service}" # cloudflare_service, cloudflare_docker, selfhosted_gateway
cert="${2}"
config="${3}"


#################################################
docker_compose=$(cat << "EOF"
  version: '3'
  services:
    httpbin:
      image: kennethreitz/httpbin
      restart: always
      container_name: httpbin
      ports:
        - 8080:80
EOF
)

#################################################
cert_json=$(cat << "EOF"
{
		"AccountTag"   : "${account}",
		"TunnelID"     : "${tunnel_id}",
		"TunnelName"   : "${tunnel_name}",
		"TunnelSecret" : "${secret}"
}
EOF
)

#################################################
config_yml=$(cat << "EOF"
tunnel: ${tunnel_id}
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


# Docker configuration
cd /tmp
# This is a herefile that is used to populate the /tmp/docker-compose.yml file. This logic is used elsewhere in this script 
echo "${docker_compose}"> /tmp/docker-compose.yml 
# cloudflared configuration
cd
#install
sudo apt-get install cloudflared
manual=false
if [ $manual ]; then
	# The package for this OS is retrieved 
	wget https://bin.equinox.io/c/VdrWdbjqyF/cloudflared-stable-linux-amd64.deb
	sudo dpkg -i cloudflared-stable-linux-amd64.deb
 else
	. /etc/os-release
	read _ UBUNTU_VERSION_NAME <<< "$VERSION"
 	VERSION="$(echo "$VERSION" | cut -f 1 -d " ")"
  	VERSION="$(echo "$a" | tr '[:upper:]' '[:lower:]')"
	 # Add cloudflare gpg key
	sudo mkdir -p --mode=0755 /usr/share/keyrings
	curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
	
	# Add this repo to your apt repositories
	echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $VERSION main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
	
	# install cloudflared
	sudo apt-get update && sudo apt-get install cloudflared
 fi
# A local user directory is first created before we can install the tunnel as a system service 
mkdir ~/.cloudflared
touch ~/.cloudflared/cert.json
touch ~/.cloudflared/config.yml
# Another herefile is used to dynamically populate the JSON credentials file 
echo "${cert_json}" > ~/.cloudflared/cert.json 
# Same concept with the Ingress Rules the tunnel will use 
echo "${config_yml}" > ~/.cloudflared/config.yml


if [ "$as" == 'service' ]; then
  # Retrieveing the docker repository for this OS
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
  # The OS is updated and docker is installed
  sudo apt update -y && sudo apt upgrade -y
  sudo apt install docker docker-compose -y 
  # Now we install the tunnel as a systemd service 
  sudo cloudflared service install
  # The credentials file does not get copied over so we'll do that manually 
  sudo cp -via ~/.cloudflared/cert.json /etc/cloudflared/
  # Now we can bring up our container(s) with docker-compose and then start the tunnel 
  cd /tmp
  sudo docker-compose up -d && sudo service cloudflared start
elif [ "$as" == 'docker' ]; then
	echo "not implemented yet"
 else 
 	echo "unknown value for how you wish to install"
	exit 1
fi
echo "Complete!"
