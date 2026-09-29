#!/usr/bin/env bash
set -euo pipefail

echo "Preparando el laboratorio M7..."

sudo apt-get update -qq
sudo apt-get install -y -qq iproute2 procps psmisc ripgrep python3 >/dev/null

ensure_user() {
  local user_name="$1"
  local user_shell="$2"
  if ! id "$user_name" >/dev/null 2>&1; then
    sudo useradd --create-home --shell "$user_shell" "$user_name"
  else
    sudo usermod --shell "$user_shell" "$user_name"
  fi
}

ensure_user contractor_ran /bin/bash
ensure_user svc_backup /bin/bash
ensure_user vendor_temp /bin/bash

if ! getent group telcoops >/dev/null 2>&1; then
  sudo groupadd telcoops
fi

sudo usermod -aG telcoops vscode
sudo usermod -aG telcoops svc_backup

# Estado inseguro intencional: cuenta temporal activa.
echo 'vendor_temp:M7-Temporary-Only!' | sudo chpasswd
sudo usermod -U vendor_temp

# Estado inseguro intencional: privilegio administrativo permanente del contractor.
sudo tee /etc/sudoers.d/contractor_ran >/dev/null <<'EOF'
contractor_ran ALL=(ALL) NOPASSWD:ALL
EOF
sudo chmod 0440 /etc/sudoers.d/contractor_ran

sudo mkdir -p /opt/telcoandina/bin /opt/telcoandina/debug

sudo tee /opt/telcoandina/secrets.env >/dev/null <<'EOF'
APP_ENV=lab
BACKUP_TARGET=simulated
API_TOKEN=training-value-not-real
EOF

sudo tee /opt/telcoandina/bin/backup.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
echo "Simulated TelcoAndina backup completed"
EOF

sudo tee /opt/telcoandina/sshd_config >/dev/null <<'EOF'
# Archivo simulado. No controla el SSH real de GitHub Codespaces.
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
EOF

sudo chown root:telcoops /opt/telcoandina/secrets.env
sudo chown root:telcoops /opt/telcoandina/bin/backup.sh
sudo chown root:root /opt/telcoandina/sshd_config

# Estados inseguros intencionales para la práctica.
sudo chmod 0644 /opt/telcoandina/secrets.env
sudo chmod 0777 /opt/telcoandina/bin/backup.sh
sudo chmod 0644 /opt/telcoandina/sshd_config

sudo tee /opt/telcoandina/debug/index.html >/dev/null <<'EOF'
TelcoAndina debug service - training environment
EOF
sudo chmod 0644 /opt/telcoandina/debug/index.html

# Evita duplicar el proceso si el script se ejecuta nuevamente.
existing_pid="$(pgrep -f 'python3 -m http.server 9090' | head -n 1 || true)"
if [[ -n "$existing_pid" ]]; then
  sudo kill "$existing_pid" 2>/dev/null || true
fi

nohup python3 -m http.server 9090 --directory /opt/telcoandina/debug \
  >/tmp/telco-debug.log 2>&1 &
echo "$!" | sudo tee /tmp/telco-debug.pid >/dev/null

sleep 1

echo
echo "M7 lab ready"
echo "Ejecuta bash ./lab/check-hardening.sh solo cuando la instructora lo indique."
