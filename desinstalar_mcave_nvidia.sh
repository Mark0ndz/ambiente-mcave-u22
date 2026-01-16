#!/bin/bash

# ==============================================================================
# SCRIPT DE DESINSTALAÇÃO: LIMPEZA TOTAL DO AMBIENTE MCAVE
# ==============================================================================

echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "ATENÇÃO: ESTE SCRIPT IRÁ DESTRUIR TODO O AMBIENTE DE SIMULAÇÃO."
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "Serão removidos: ElmerFEM, ParaView, OpenFOAM, MKL e configurações."
echo ""
echo ">>> PARA CANCELAR, PRESSIONE: Ctrl + C <<<"
echo ""

# Contagem regressiva de 10 segundos (Funciona mesmo via wget | bash)
for i in {10..1}; do
    echo -ne "A limpeza começará em $i segundos... \r"
    sleep 1
done

echo -e "\n\n>>> INICIANDO REMOÇÃO AGORA..."

# ==============================================================================
# 1. REMOVENDO ELMERFEM
# ==============================================================================
echo "[1/6] Removendo ElmerFEM..."
cd $HOME
rm -rf elmer 2>/dev/null
sudo rm -f /usr/local/bin/Elmer* /usr/local/bin/elmer*
sudo rm -rf /usr/local/share/ElmerGUI /usr/local/share/elmerfem
sudo rm -rf /usr/local/lib/elmerfem /usr/local/lib/libelmer*

# ==============================================================================
# 2. REMOVENDO PARAVIEW
# ==============================================================================
echo "[2/6] Removendo ParaView 6..."
sudo rm -rf /opt/paraview6

# ==============================================================================
# 3. REMOVENDO OPENFOAM 10
# ==============================================================================
echo "[3/6] Removendo OpenFOAM 10..."
sudo apt purge -y openfoam10
sudo rm -f /etc/apt/trusted.gpg.d/openfoam.asc
sudo add-apt-repository --remove -y http://dl.openfoam.org/ubuntu 2>/dev/null

# ==============================================================================
# 4. REMOVENDO INTEL ONEAPI MKL
# ==============================================================================
echo "[4/6] Removendo Intel OneAPI MKL..."
sudo apt purge -y intel-basekit intel-mkl*
sudo rm -rf /opt/intel
sudo rm -f /etc/apt/sources.list.d/oneAPI.list
sudo rm -f /usr/share/keyrings/oneapi-archive-keyring.gpg

# ==============================================================================
# 5. REMOVENDO DEPENDÊNCIAS
# ==============================================================================
echo "[5/6] Limpando bibliotecas e dependências..."
sudo apt purge -y \
  libopenmpi-dev openmpi-bin libopenmpi3 \
  libblas-dev liblapack-dev \
  libscalapack-mpi-dev libscalapack-openmpi-dev \
  libmumps-dev libmumps-headers-dev libmumps-5.4 \
  libhypre-dev \
  libparmetis-dev parmetis-doc \
  libmetis-dev libmetis5 \
  libscotch-dev \
  gmsh \
  elmerfem-csc elmerfem-gui elmerfem-common || true

sudo apt autoremove -y
sudo apt clean

# ==============================================================================
# 6. LIMPANDO .BASHRC
# ==============================================================================
echo "[6/6] Restaurando .bashrc..."
cp ~/.bashrc ~/.bashrc.backup.clean.$(date +%F_%H-%M)
sed -i '/# --- MCAVE CONFIG START ---/,/# --- MCAVE CONFIG END ---/d' ~/.bashrc

echo ""
echo "================================================================="
echo "LIMPEZA CONCLUÍDA!"
echo "================================================================="
