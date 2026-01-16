#!/bin/bash

# ==============================================================================
# SCRIPT DE INSTALAÇÃO: AMBIENTE MCAVE + NVIDIA PERFORMANCE (UBUNTU 22.04)
# Autor: Adaptado para MCAVE
# Data: Janeiro/2026
# ==============================================================================

set -e # Para o script se houver erro crítico

echo ">>> INICIANDO SETUP MCAVE (VERSÃO NVIDIA RTX 4060) <<<"

# ==============================================================================
# ETAPA 0: VALIDAÇÃO DE HARDWARE
# ==============================================================================
echo ""
echo "[0/8] VERIFICANDO COMPATIBILIDADE DE HARDWARE..."

# Verifica se existe uma controladora VGA ou 3D da NVIDIA
if lspci | grep -i "NVIDIA" > /dev/null; then
    echo "  -> GPU NVIDIA detectada."
    
    # Verifica especificamente se é uma série 4060 (ou ajustável para 40xx)
    if lspci | grep -i "4060" > /dev/null; then
        echo "  -> Modelo RTX 4060 confirmado. Prosseguindo..."
    else
        echo "  -> AVISO: GPU NVIDIA detectada, mas não parece ser uma RTX 4060."
        echo "  -> O script continuará, mas verifique a compatibilidade do driver 580."
        read -p "  Pressione ENTER para continuar ou Ctrl+C para cancelar."
    fi
else
    echo "ERRO CRÍTICO: Nenhuma GPU NVIDIA detectada."
    echo "Este script é exclusivo para sistemas com hardware NVIDIA."
    exit 1
fi

# ==============================================================================
# ETAPA 1: LIMPEZA COMPLETA (DRIVERS + ELMER)
# ==============================================================================
echo ""
echo "-----------------------------------------------------------------"
echo "[1/8] EXECUTANDO LIMPEZA PROFUNDA (DRIVERS E SOFTWARES)..."
echo "-----------------------------------------------------------------"
echo "ATENÇÃO: A tela pode piscar ou mudar a resolução durante este processo."

# 1.1 Limpeza de Instalações MCAVE (Elmer, etc)
cd $HOME
rm -rf elmer 2>/dev/null
rm -rf $HOME/elmer/install 2>/dev/null
sudo rm -f /usr/local/bin/Elmer* /usr/local/bin/elmer*
sudo rm -rf /usr/local/share/ElmerGUI /usr/local/share/elmerfem
sudo rm -rf /usr/local/lib/elmerfem /usr/local/lib/libelmer*

# 1.2 Limpeza de Dependências (Protegendo MKL)
echo ">>> Removendo bibliotecas conflitantes..."
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

# 1.3 Limpeza de Drivers NVIDIA Antigos (Conforme solicitado)
echo ">>> Purgando drivers NVIDIA antigos..."
sudo apt-get purge 'nvidia.*' -y
sudo apt-get autoremove -y
sudo apt-get autoclean

# ==============================================================================
# ETAPA 2: INSTALAÇÃO DO DRIVER NVIDIA 580 E PREPARAÇÃO
# ==============================================================================
echo ""
echo "-----------------------------------------------------------------"
echo "[2/8] INSTALANDO DRIVER NVIDIA 580 E FERRAMENTAS..."
echo "-----------------------------------------------------------------"

# 2.1 Repositórios e Update
sudo add-apt-repository ppa:graphics-drivers/ppa -y
sudo apt update

# 2.2 Utilitários Básicos (Incluindo 'tree')
sudo apt install -y build-essential git cmake gfortran wget curl \
    cpufrequtils sysfsutils gpg-agent software-properties-common tree

# 2.3 Instalação do Driver
# echo ">>> Baixando e instalando Nvidia Driver 580 (Isso pode demorar)..."
# sudo apt install -y nvidia-driver-580 nvidia-utils-580 nvidia-settings

# ==============================================================================
# ETAPA 3: CONFIGURAÇÃO DE PERFORMANCE (SISTEMA)
# ==============================================================================
echo ""
echo "-----------------------------------------------------------------"
echo "[3/8] APLICANDO TWEAKS DE PERFORMANCE (KERNEL/CPU)..."
echo "-----------------------------------------------------------------"

# 3.1 CPU Governor (Performance)
echo ">>> Configurando CPU para Performance..."
sudo cpufreq-set -r -g performance || true
if ! grep -q "scaling_governor = performance" /etc/sysfs.conf; then
    echo "devices/system/cpu/cpu*/cpufreq/scaling_governor = performance" | sudo tee -a /etc/sysfs.conf
fi

# 3.2 NVIDIA Prime Select (Força o uso da GPU Discreta)
echo ">>> Definindo NVIDIA como GPU primária..."
sudo prime-select nvidia

# 3.3 DRM Mode Setting (Para evitar tearing e melhorar sync)
echo ">>> Ativando NVIDIA DRM Modeset..."
echo "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia-kms.conf
sudo update-initramfs -u

# ==============================================================================
# ETAPA 4: PERSISTÊNCIA DAS CONFIGURAÇÕES VISUAIS (AUTOSTART)
# ==============================================================================
echo ""
echo "-----------------------------------------------------------------"
echo "[4/8] CRIANDO SCRIPTS DE INICIALIZAÇÃO E AUTOSTART..."
echo "-----------------------------------------------------------------"

# Configurações como 'nvidia-settings' precisam do X server rodando.
# Criaremos um script que roda ao fazer login.

mkdir -p ~/.config/autostart

# Criação do arquivo .desktop com cuidado nas aspas e escapes
cat <<EOF > ~/.config/autostart/nvidia-performance.desktop
[Desktop Entry]
Type=Application
Exec=sh -c 'sleep 5 && nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=1" && nvidia-settings -a "CurrentMetaMode=\$(nvidia-settings -q CurrentMetaMode -t | sed "s/\\}/, ForceFullCompositionPipeline=On\\}/g")"'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=NVIDIA Performance Mode
Comment=Forca PowerMizer e FullCompositionPipeline no login
EOF

chmod +x ~/.config/autostart/nvidia-performance.desktop
echo ">>> Autostart configurado. As correções de lag aplicarão após o login."

# ==============================================================================
# ETAPA 5: INTEL ONEAPI MKL
# ==============================================================================
echo ""
echo "-----------------------------------------------------------------"
echo "[5/8] INSTALANDO INTEL ONEAPI MKL..."
echo "-----------------------------------------------------------------"

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
# ETAPA 6: ELMERFEM (COMPILAÇÃO COM MKL)
# ==============================================================================
echo ""
echo "-----------------------------------------------------------------"
echo "[6/8] COMPILANDO ELMERFEM (LINKADO COM MKL)..."
echo "-----------------------------------------------------------------"

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
# ETAPA 7: FERRAMENTAS E OPENFOAM
# ==============================================================================
echo ""
echo "-----------------------------------------------------------------"
echo "[7/8] INSTALANDO OPENFOAM 10, GMSH E PARAVIEW..."
echo "-----------------------------------------------------------------"

# OpenFOAM
sudo sh -c "wget -O - https://dl.openfoam.org/gpg.key > /etc/apt/trusted.gpg.d/openfoam.asc"
sudo add-apt-repository -y http://dl.openfoam.org/ubuntu
sudo apt update
sudo apt -y install openfoam10 gmsh

# ParaView (LINK DO GITHUB)
# ATENÇÃO: Substitua SEU_USUARIO abaixo pelo seu username do GitHub se já criou a release
PV_RELEASE_URL="https://github.com/Mark0ndz/ambiente-mcave-u22/releases/download/v1.0/ParaView-6.0.1-MPI-Linux-Python3.12-x86_64.tar.gz"
# Fallback para o oficial caso o usuário não altere, para o script não quebrar
OFFICIAL_URL="https://www.paraview.org/paraview-downloads/download.php?submit=Download&version=6.0&type=binary&os=Linux&downloadFile=ParaView-6.0.1-MPI-Linux-Python3.10-x86_64.tar.gz"

# Usa o link oficial se o do GitHub ainda estiver com "SEU_USUARIO"
if [[ "$PV_RELEASE_URL" == *"SEU_USUARIO"* ]]; then
    echo ">>> Aviso: Link do GitHub não configurado. Usando servidor oficial (Lento)..."
    FINAL_URL="$OFFICIAL_URL"
else
    FINAL_URL="$PV_RELEASE_URL"
fi

PV_FILE="ParaView-6.0.1.tar.gz"

if [ ! -d "/opt/paraview6" ]; then
    echo ">>> Baixando ParaView..."
    wget -O /tmp/$PV_FILE "$FINAL_URL"
    echo ">>> Instalando em /opt/paraview6..."
    sudo mkdir -p /opt/paraview6
    sudo tar -xzf /tmp/$PV_FILE -C /opt/paraview6 --strip-components=1
    rm /tmp/$PV_FILE
fi

# ==============================================================================
# ETAPA 8: CONFIGURAÇÃO .BASHRC
# ==============================================================================
echo ""
echo "-----------------------------------------------------------------"
echo "[8/8] FINALIZANDO CONFIGURAÇÃO DO AMBIENTE..."
echo "-----------------------------------------------------------------"

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

# 5. PARAVIEW 6 (GPU OFFLOADING)
export PARAVIEW_HOME=/opt/paraview6
export PATH=$PARAVIEW_HOME/bin:$PATH
unalias paraview 2>/dev/null
unalias paraFoam 2>/dev/null

paraview() {
    echo ">> Iniciando ParaView 6 (RTX 4060)..."
    env -u LD_LIBRARY_PATH -u PYTHONPATH -u QT_PLUGIN_PATH \
    LC_ALL=C.UTF-8 \
    __NV_PRIME_RENDER_OFFLOAD=1 \
    __GLX_VENDOR_LIBRARY_NAME=nvidia \
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
echo "INSTALAÇÃO COMPLETA!"
echo "================================================================="
echo "O sistema precisa ser reiniciado para:"
echo "1. Carregar o novo Driver NVIDIA 580."
echo "2. Ativar o DRM Modeset e Autostart de Performance."
echo ""
echo "Por favor, reinicie agora com: sudo reboot"
echo "================================================================="

