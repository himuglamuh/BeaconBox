#!/bin/bash -e

echo "▶️ Running beaconbox config update..."
script_dir=$(dirname "$0")
pi_config_file="$script_dir/pi-gen-config"
pi_template_file="$script_dir/pi-gen-config-template"
config_file="$script_dir/../config.yaml"

if [ ! -f "$pi_template_file" ]; then
    echo "❌ Config file $pi_template_file does not exist. Exiting."
    exit 1
fi

if [ ! -f "$config_file" ]; then
    echo "❌ Config file $config_file does not exist. Exiting."
    exit 1
fi

update_config() {
    local key="$1"
    local value="$2"
    sed -i "s|$key|$value|g" "$pi_config_file"
}

get_yaml_value() {
  local key="$2"
  awk -v k="$key" '
    $1 == k ":" {
      val = $2
      for (i = 3; i <= NF; i++) val = val " " $i
      # Remove quotes, trailing comments
      sub(/#.*/, "", val)
      gsub(/^ *"/, "", val)
      gsub(/" *$/, "", val)
      gsub(/^ *'\''/, "", val)
      gsub(/'\'' *$/, "", val)
      gsub(/^ +| +$/, "", val)
      print val
    }
  ' "$1"
}

echo "📂 Copying template config to $pi_config_file..."
cp "$pi_template_file" "$pi_config_file"

echo "🤲 Extracting username and password from $config_file..."
username=$(get_yaml_value "$config_file" "username")
password=$(get_yaml_value "$config_file" "password")
ssh=$(get_yaml_value "$config_file" "enable_ssh")

if [ -z "$username" ] || [ -z "$password" ]; then
    echo "❌ Username or password not found in $config_file. Using default beaconbox/beaconbox."
    username="beaconbox"
    password="beaconbox"
fi

if [ -z "$ssh" ]; then
    echo "❌ SSH setting not found in $config_file. Using default '1'."
    ssh="1"
fi

if [ "$ssh" != "0" ] && [ "$ssh" != "1" ]; then
    echo "❌ Invalid SSH setting '$ssh' in $config_file. Using default '1'."
    ssh="1"
fi

echo "✏️ Setting username and password in $config_file..."
update_config "%username%" "$username"
update_config "%password%" "$password"
update_config "%enable_ssh%" "$ssh"

echo "✅ Config update complete"
