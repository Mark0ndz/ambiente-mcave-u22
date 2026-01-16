#!/bin/bash

# ==============================================================================
# SCRIPT DE INSTALAÇÃO: AMBIENTE MCAVE (GERAL) - UBUNTU 22.04
# Autor: Adaptado para MCAVE
# Data: Janeiro/2026
# ==============================================================================

set -e

echo ">>> INICIANDO SETUP MCAVE (VERSÃO GERAL) <<<"
echo ">>> Este script instala os softwares de simulação (CPU Based)."

# ==============================================================================
# ETAPA 1: LIMPEZA DE SOFTWARES (ELMER E DEPENDÊNCIAS)
# ==============================================================================
echo ""
echo "[1/6] EXECUTANDO LIMPEZA DE SOFTWARES..."

# Limpeza de pastas locais
cd $HOME
rm -rf elmer 2>/dev/null
rm -rf $HOME/elmer/install 2>/dev/null

# Limpeza de binários
sudo rm -f /usr/local/bin/Elmer* /usr/local/bin/elmer*
sudo rm -rf /usr/local/share/ElmerGUI /usr/local/share/elmerfem
sudo rm -rf /usr/local/lib/elmerfem /usr/local/lib/libelmer*

# Limpeza de bibliotecas conflitantes (Protegendo a MKL)
sudo apt purge -y \
  libopenmpi-dev openmpi-bin libopenmpi3 \
  libblas-dev liblapack-dev \
  libscalapack-mpi-dev libscalapack-openmpi-dev \
  libmumps-dev libmumps-headers-dev libmumps-5.4 \
  libhypre-dev \
  libparmetis-dev parmetis-doc \
  libmetis-dev libmetis5 \
  libscotch-dev \
  elmerfem-csc elmerfem-gui elmerfem-common || true

sudo apt autoremove -y
sudo apt clean

# ==============================================================================
# ETAPA 2: PREPARAÇÃO DO SISTEMA, INTERFACE E PERFORMANCE
# ==============================================================================
echo ""
echo "[2/6] PREPARANDO SISTEMA (INTERFACE, TECLADO E UTILITÁRIOS)..."

# 2.1 Atualização e Correção
echo ">>> Corrigindo pacotes e atualizando..."
sudo dpkg --configure -a
sudo apt update

# 2.2 Interface e Editor (Dark Mode)
# (|| true evita erro se rodar via SSH sem interface gráfica)
echo ">>> Configurando Tema Escuro (Gedit/Sistema)..."
gsettings set org.gnome.gedit.preferences.editor scheme 'oblivion' 2>/dev/null || true
gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-dark' 2>/dev/null || true

# 2.3 Layout de Teclado (ABNT2)
echo ">>> Configurando Teclado ABNT2..."
setxkbmap -model abnt2 -layout br 2>/dev/null || true
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'br')]" 2>/dev/null || true

# 2.4 Instalação de Utilitários
echo ">>> Instalando compiladores e ferramentas..."
sudo apt install -y build-essential git cmake gfortran wget curl \
    cpufrequtils sysfsutils gpg-agent software-properties-common tree

# 2.5 Configuração de CPU (Performance)
echo ">>> Ajustando governador da CPU..."
sudo cpufreq-set -r -g performance || true
if ! grep -q "scaling_governor = performance" /etc/sysfs.conf; then
    echo "devices/system/cpu/cpu*/cpufreq/scaling_governor = performance" | sudo tee -a /etc/sysfs.conf
fi

# ==============================================================================
# ETAPA 3: INTEL ONEAPI MKL
# ==============================================================================
echo ""
echo "[3/6] INSTALANDO INTEL ONEAPI MKL..."

if [ ! -d "/opt/intel/oneapi/mkl" ]; then
    wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
    | gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list
    sudo apt update
    sudo apt install -y intel-basekit
else
    echo ">>> Intel MKL detectado. Pulando."
fi

# ==============================================================================
# ETAPA 4: ELMERFEM (COMPILAÇÃO)
# ==============================================================================
echo ""
echo "[4/6] COMPILANDO ELMERFEM..."

# Dependências
sudo apt install -y \
  libblas-dev liblapack-dev cmake-qt-gui libscalapack-mpi-dev \
  libqt5xml5 qtbase5-dev qt5-qmake qtdeclarative5-dev qtscript5-dev \
  libqt5svg5-dev qtcreator libmumps-dev parmetis-doc libparmetis-dev \
  libmetis-dev libscotch-dev libhypre-dev mpich

# Compilação
cd $HOME
mkdir -p elmer/build
cd elmer
if [ ! -d "elmerfem" ]; then
    git clone https://github.com/ElmerCSC/elmerfem.git
else
    cd elmerfem && git pull && cd ..
fi
cd build

cmake \
  -DWITH_ELMERGUI:BOOL=TRUE \
  -DWITH_LUA=TRUE \
  -DWITH_MKL=TRUE \
  -DWITH_MPI:BOOL=TRUE \
  -DWITH_MATC:BOOL=TRUE \
  -DWITH_Mumps=TRUE \
  -DWITH_PARAVIEW:BOOL=TRUE \
  -DWITH_QWT:BOOL=FALSE \
  -DWITH_QT5:BOOL=TRUE \
  -DWITH_Zoltan=FALSE \
  -DMETIS_INSTALL=TRUE \
  -DMETIS_SHARED=TRUE \
  -DWITH_Hypre:BOOL=TRUE \
  -DHypre_INCLUDE_DIR=/usr/include/hypre \
  -DCMAKE_INSTALL_PREFIX=../install ../elmerfem

make -j$(nproc) install

# ==============================================================================
# ETAPA 5: OPENFOAM, GMSH E PARAVIEW
# ==============================================================================
echo ""
echo "[5/6] INSTALANDO OPENFOAM 10, GMSH E PARAVIEW..."

# OpenFOAM
sudo sh -c "wget -O - https://dl.openfoam.org/gpg.key > /etc/apt/trusted.gpg.d/openfoam.asc"
sudo add-apt-repository -y http://dl.openfoam.org/ubuntu
sudo apt update
sudo apt -y install openfoam10 gmsh

# ParaView (Seu Link do GitHub)
# ATENÇÃO: Se necessário, atualize este link para sua Release do GitHub
PV_URL="https://github.com/Mark0ndz/ambiente-mcave-u22/releases/download/v1.0/ParaView-6.0.1-MPI-Linux-Python3.10-x86_64.tar.gz"
PV_FILE="ParaView-6.0.1.tar.gz"

if [ ! -d "/opt/paraview6" ]; then
    echo ">>> Baixando ParaView..."
    wget -O /tmp/$PV_FILE "$PV_URL"
    echo ">>> Instalando em /opt/paraview6..."
    sudo mkdir -p /opt/paraview6
    sudo tar -xzf /tmp/$PV_FILE -C /opt/paraview6 --strip-components=1
    rm /tmp/$PV_FILE
fi

# ==============================================================================
# ETAPA 6: CONFIGURAÇÃO .BASHRC
# ==============================================================================
echo ""
echo "[6/6] FINALIZANDO CONFIGURAÇÃO DO AMBIENTE..."

cp ~/.bashrc ~/.bashrc.backup.$(date +%F_%H-%M)
sed -i '/# --- MCAVE CONFIG START ---/,/# --- MCAVE CONFIG END ---/d' ~/.bashrc

cat << 'EOF' >> ~/.bashrc

# --- MCAVE CONFIG START ---

# 1. INTEL MKL
LATEST_MKL=$(ls -d /opt/intel/oneapi/mkl/20* 2>/dev/null | sort -V | tail -n1)
if [ -n "$LATEST_MKL" ] && [ -f "$LATEST_MKL/env/vars.sh" ]; then
    source "$LATEST_MKL/env/vars.sh" > /dev/null 2>&1
fi

# 2. ELMERFEM
export ELMER_HOME=$HOME/elmer/install
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ELMER_HOME/lib
export PATH=$PATH:$ELMER_HOME/bin
alias elmer='ElmerGUI'

# 3. OPENFOAM
[ -f /opt/openfoam10/etc/bashrc ] && source /opt/openfoam10/etc/bashrc

# 4. TOOLS
alias mesh='gmsh'
alias refresh='source ~/.bashrc'

# 5. PARAVIEW 6 (Standard)
export PARAVIEW_HOME=/opt/paraview6
export PATH=$PARAVIEW_HOME/bin:$PATH
unalias paraview 2>/dev/null
unalias paraFoam 2>/dev/null

paraview() {
    # Comando padrão sem flags da NVIDIA (Pode ser ajustado se instalar Drivers)
    env -u LD_LIBRARY_PATH -u PYTHONPATH -u QT_PLUGIN_PATH \
    LC_ALL=C.UTF-8 \
    /opt/paraview6/bin/paraview "$@" &
}

paraFoam() {
    caseName=${PWD##*/}
    [ ! -f "$caseName.foam" ] && touch "$caseName.foam"
    paraview "$caseName.foam"
}
# --- MCAVE CONFIG END ---
EOF

echo ""
echo "================================================================="
echo "INSTALAÇÃO DOS SOFTWARES CONCLUÍDA!"
echo "================================================================="
echo "Ambiente configurado:"
echo "- Teclado: ABNT2"
echo "- Tema: Dark Mode"
echo "- Softwares: Elmer, OpenFOAM, ParaView 6, MKL, Gmsh"
echo ""
echo "Para instalar Drivers NVIDIA, consulte o guia separado."
echo "Reinicie o terminal ou digite: source ~/.bashrc"
echo "================================================================="
