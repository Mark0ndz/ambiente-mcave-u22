#!/bin/bash

# ==============================================================================
# SCRIPT DE DESINSTALAÇÃO: LIMPEZA TOTAL DO AMBIENTE MCAVE
# ==============================================================================
# O QUE ESTE SCRIPT FAZ:
# 1. Remove ElmerFEM (Fontes e Instalação).
# 2. Remove ParaView 6 (/opt/paraview6).
# 3. Remove OpenFOAM 10 e seus repositórios.
# 4. Remove Intel OneAPI MKL e seus repositórios.
# 5. Remove bibliotecas de dependência instaladas (MUMPS, Hypre, etc).
# 6. Limpa as configurações adicionadas ao .bashrc.
# ==============================================================================

echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "ATENÇÃO: ESTE SCRIPT IRÁ REMOVER TODO O AMBIENTE DE SIMULAÇÃO."
echo "Isso inclui: Elmer, OpenFOAM, ParaView, Intel MKL e dependências."
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo ""
read -p "Tem certeza que deseja continuar? (s/N): " confirm

if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
    echo "Operação cancelada."
    exit 1
fi

echo ""
echo ">>> INICIANDO REMOÇÃO..."

# ==============================================================================
# 1. REMOVENDO ELMERFEM
# ==============================================================================
echo "[1/6] Removendo ElmerFEM..."
cd $HOME
rm -rf elmer 2>/dev/null
# Remove binários do sistema se houver
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
# Remove a chave e o repositório
sudo rm -f /etc/apt/trusted.gpg.d/openfoam.asc
sudo add-apt-repository --remove -y http://dl.openfoam.org/ubuntu 2>/dev/null

# ==============================================================================
# 4. REMOVENDO INTEL ONEAPI MKL
# ==============================================================================
echo "[4/6] Removendo Intel OneAPI MKL..."
sudo apt purge -y intel-basekit intel-mkl*
sudo rm -rf /opt/intel
# Remove repositório e chaves
sudo rm -f /etc/apt/sources.list.d/oneAPI.list
sudo rm -f /usr/share/keyrings/oneapi-archive-keyring.gpg

# ==============================================================================
# 5. REMOVENDO DEPENDÊNCIAS DE COMPILAÇÃO
# ==============================================================================
echo "[5/6] Limpando bibliotecas e dependências..."
# Remove bibliotecas matemáticas e de MPI instaladas pelo script
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

# Limpeza automática de pacotes órfãos
sudo apt autoremove -y
sudo apt clean

# ==============================================================================
# 6. LIMPANDO .BASHRC
# ==============================================================================
echo "[6/6] Restaurando .bashrc..."

# Faz um backup antes de mexer
cp ~/.bashrc ~/.bashrc.backup.clean.$(date +%F_%H-%M)

# Remove o bloco de configuração MCAVE
sed -i '/# --- MCAVE CONFIG START ---/,/# --- MCAVE CONFIG END ---/d' ~/.bashrc

echo ""
echo "================================================================="
echo "LIMPEZA CONCLUÍDA!"
echo "================================================================="
echo "O sistema foi restaurado (Softwares de simulação removidos)."
echo "Nota: Configurações de interface (Dark Mode) e Teclado foram mantidas."
echo "Reinicie o terminal para aplicar a limpeza do PATH."
echo "================================================================="