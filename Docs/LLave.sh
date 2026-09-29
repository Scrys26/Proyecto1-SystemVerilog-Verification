#!/bin/bash

# ==========================================
# CONFIGURACIÓN
# ==========================================

EMAIL="TU_CORREO@EJEMPLO.COM"
KEY_NAME="github_proyecto"

# ==========================================
# CREAR LLAVE SSH
# ==========================================

echo "=========================================="
echo " Creando llave SSH para GitHub"
echo "=========================================="

echo "Correo: $EMAIL"
echo "Llave: ~/.ssh/$KEY_NAME"

ssh-keygen -t ed25519 \
    -C "$EMAIL" \
    -f "$HOME/.ssh/$KEY_NAME"

# ==========================================
# MOSTRAR LLAVE PÚBLICA
# ==========================================

echo ""
echo "=========================================="
echo " LLAVE PÚBLICA"
echo "=========================================="

cat "$HOME/.ssh/$KEY_NAME.pub"

echo ""
echo "=========================================="
echo " Copia la llave anterior y agrégala en:"
echo " GitHub -> Settings -> SSH and GPG keys"
echo "=========================================="

# ==========================================
# CONFIGURAR SSH
# ==========================================

echo ""
echo "Configurando ~/.ssh/config..."

touch "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"

cat >> "$HOME/.ssh/config" << EOF

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/$KEY_NAME
    IdentitiesOnly yes
EOF

# ==========================================
# PRUEBA
# ==========================================

echo ""
echo "=========================================="
echo " Prueba de conexión"
echo "=========================================="

ssh -T git@github.com

echo ""
echo "=========================================="
echo " Configuración terminada"
echo "=========================================="