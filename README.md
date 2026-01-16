# Ambiente MCAVE (Ubuntu 22.04)

Script automatizado para configuração de estação de simulação CFD/FEA.

## O que este script instala:
- **Intel OneAPI MKL** (Bibliotecas matemáticas otimizadas)
- **ElmerFEM** (Compilado do zero, linkado com MKL e MUMPS)
- **OpenFOAM 10** (Nativo)
- **ParaView 6.0.1** (Versão Binária MPI, rodando via GPU Offload)
- **Gmsh**

## 🚀 Como Instalar

Abra seu terminal no Ubuntu 22.04 e rode o comando abaixo (não precisa de sudo no início, ele pedirá a senha quando necessário):

```bash
# Instalação rápida:
wget -O- tinyurl.com/mcave-install | tr -d '\r' | bash
```

## ❌ Como Desinstalar

```bash
# Desinstalação completa:
wget -O- tinyurl.com/mcave-uninstall | tr -d '\r' | bash
```
