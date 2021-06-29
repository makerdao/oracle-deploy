![Nix Package Manager](https://forthebadge.com/images/badges/powered-by-black-magic.svg) 
![No promises whatsoever](https://forthebadge.com/images/badges/works-on-my-machine.svg)

# Oracle Deploy

This is a set of scripts to allow for an easy setup of oracles for testing.

## Quick Start

### Prerequisites

```shell
# Nix package manager (see https://nixos.org/download.html for more options)
curl -L https://nixos.org/nix/install | sh
```

### Setup

```shell
# Get the repo
git clone https://github.com/makerdao/oracle-deploy.git
# Use the example directory as the base
cp -r oracle-deploy/example my-env
# Create a secret dir  
mkdir -p my-env/secret
# Add AWS credentials
echo '{"aws_access_key_id":"AWS_ID","aws_secret_access_key":"AWS_KEY"}' > my-env/secret/aws.json
# Enter the directory's Nix Shell (might take a while when done for the first time)
nix-shell my-env/shell.nix
# Create a secret ssh-key
ssh-keygen -t rsa -b 2048 -C "my-env-access" -f secret/ssh_key
# Add Graphite credentials
echo 'login:api_key' > secret/graphite_api_key
# Add some additional keys for exchange APIs with restricted access
echo '{"openexchangerates":{"apiKey":"KEY"}}' > secret/origins.json
```

### Initialize Environment

```shell
terraform init
terraform apply
nixiform init
```

### Configure created VPS machines

```shell
nixiform push
```
