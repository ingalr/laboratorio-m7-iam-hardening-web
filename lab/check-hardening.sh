#!/usr/bin/env bash
set -u

pass_count=0
fail_count=0

pass() {
  printf 'PASS  %s\n' "$1"
  pass_count=$((pass_count + 1))
}

fail() {
  printf 'FAIL  %s\n' "$1"
  fail_count=$((fail_count + 1))
}

echo "M7 hardening check"
echo "=================="

if [[ ! -e /etc/sudoers.d/contractor_ran ]]; then
  pass "El contractor no conserva la regla administrativa permanente"
else
  fail "Existe una regla sudo permanente para contractor_ran"
fi

svc_shell="$(getent passwd svc_backup | cut -d: -f7)"
if [[ "$svc_shell" == "/usr/sbin/nologin" ]]; then
  pass "svc_backup no permite login interactivo"
else
  fail "svc_backup conserva un shell interactivo: $svc_shell"
fi

vendor_status="$(sudo passwd -S vendor_temp 2>/dev/null | awk '{print $2}')"
if [[ "$vendor_status" == "L" ]]; then
  pass "vendor_temp está bloqueada"
else
  fail "vendor_temp continúa activa"
fi

secret_mode="$(sudo stat -c '%a' /opt/telcoandina/secrets.env)"
if [[ "$secret_mode" == "640" ]]; then
  pass "secrets.env tiene permisos 640"
else
  fail "secrets.env tiene permisos $secret_mode"
fi

backup_mode="$(sudo stat -c '%a' /opt/telcoandina/bin/backup.sh)"
if [[ "$backup_mode" == "750" ]]; then
  pass "backup.sh tiene permisos 750"
else
  fail "backup.sh tiene permisos $backup_mode"
fi

root_login="$(sudo awk '$1=="PermitRootLogin" {print $2}' /opt/telcoandina/sshd_config | tail -n 1)"
password_auth="$(sudo awk '$1=="PasswordAuthentication" {print $2}' /opt/telcoandina/sshd_config | tail -n 1)"
if [[ "$root_login" == "no" && "$password_auth" == "no" ]]; then
  pass "La configuración SSH simulada deshabilita root y contraseñas"
else
  fail "La configuración SSH simulada conserva directivas débiles"
fi

if ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq '(^|:)9090$'; then
  fail "El servicio de debug continúa escuchando en TCP/9090"
else
  pass "TCP/9090 no está escuchando"
fi

echo "=================="
printf 'Resultado: %d PASS, %d FAIL\n' "$pass_count" "$fail_count"

if (( fail_count > 0 )); then
  exit 1
fi
