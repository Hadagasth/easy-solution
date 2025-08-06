#!/bin/bash

# Define o arquivo de saída para o relatório combinado
OUTPUT_FILE="server_and_log_analysis_report_V7_$(date +%Y%m%d_%H%M%S).txt"
LOG_DIR="/var/log"
MAX_LOG_LINES=10000 # Limite de linhas para extrair de cada log individual

# Limpa o arquivo de saída se já existir
> "$OUTPUT_FILE"

echo "--- RELATÓRIO DE ANÁLISE ABRANGENTE DO SERVIDOR LINUX ---" >> "$OUTPUT_FILE"
echo "Gerado em: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# --- Seção 1: Visão Geral do Sistema ---
echo "## SEÇÃO 1: VISÃO GERAL DO SISTEMA" >> "$OUTPUT_FILE"
echo "Esta seção fornece um resumo do estado atual do servidor, incluindo uptime, carga, uso de recursos e status de rede." >> "$OUTPUT_FILE"
echo "----------------------------------------------------------------------------------" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Coleta a data e hora atual
echo "### Data e Hora da Análise ###" >> "$OUTPUT_FILE"
date >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Coleta informações de Uptime e Carga do Sistema
echo "### Uptime e Carga do Sistema ###" >> "$OUTPUT_FILE"
uptime >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Histórico de Carga do Sistema (últimos 5 minutos)
echo "### Histórico de Carga do Sistema (últimos 5 min) ###" >> "$OUTPUT_FILE"
echo "NOTA: Mostra a carga média dos últimos 1, 5 e 15 minutos detalhadamente." >> "$OUTPUT_FILE"
if [ -f /proc/loadavg ]; then
    echo "Carga atual detalhada:" >> "$OUTPUT_FILE"
    cat /proc/loadavg >> "$OUTPUT_FILE"
    echo "Número de CPUs disponíveis:" >> "$OUTPUT_FILE"
    nproc >> "$OUTPUT_FILE"
    echo "Porcentagem de carga por CPU (carga de 1 min / número de CPUs * 100):" >> "$OUTPUT_FILE"
    awk '{print ($1 / '$(nproc)') * 100 "%"}' /proc/loadavg >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# Coleta informações de Uso de CPU
echo "### Uso de CPU (Top 5 Processos por Uso de CPU) ###" >> "$OUTPUT_FILE"
ps -eo pcpu,pid,user,args --sort=-pcpu | head -n 6 >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Uso de CPU por Core
echo "### Uso de CPU por Core (mpstat) ###" >> "$OUTPUT_FILE"
echo "NOTA: Requer o pacote 'sysstat' instalado. Mostra uso individual por core de CPU." >> "$OUTPUT_FILE"
if command -v mpstat &> /dev/null; then
    mpstat -P ALL 1 1 >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao executar 'mpstat'. Verifique as permissões." >> "$OUTPUT_FILE"
else
    echo "Comando 'mpstat' não encontrado. Instale o pacote 'sysstat'." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Temperatura da CPU (se disponível)
echo "### Temperatura da CPU ###" >> "$OUTPUT_FILE"
if command -v sensors &> /dev/null; then
    sensors >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao executar 'sensors'." >> "$OUTPUT_FILE"
elif [ -d /sys/class/thermal ]; then
    echo "Temperaturas disponíveis em /sys/class/thermal:" >> "$OUTPUT_FILE"
    for thermal_zone in /sys/class/thermal/thermal_zone*/temp; do
        if [ -f "$thermal_zone" ]; then
            zone_name=$(basename $(dirname "$thermal_zone"))
            temp=$(cat "$thermal_zone" 2>/dev/null)
            if [ -n "$temp" ]; then
                echo "  $zone_name: $((temp/1000))°C" >> "$OUTPUT_FILE"
            fi
        fi
    done
else
    echo "Informações de temperatura não disponíveis." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# Coleta informações de Uso de Memória
echo "### Uso de Memória (Total, Usado, Livre) ###" >> "$OUTPUT_FILE"
free -h >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "### Uso de Memória (Top 5 Processos por Uso de Memória) ###" >> "$OUTPUT_FILE"
ps -eo pmem,pid,user,args --sort=-pmem | head -n 6 >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Swap
echo "### Análise Detalhada de Swap ###" >> "$OUTPUT_FILE"
echo "Dispositivos de Swap ativos:" >> "$OUTPUT_FILE"
swapon --show >> "$OUTPUT_FILE" 2>&1 || echo "Nenhum dispositivo de swap ativo ou erro." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Processos que mais utilizam Swap (Top 10):" >> "$OUTPUT_FILE"
if [ -d /proc ]; then
    for pid in /proc/[0-9]*; do
        if [ -f "$pid/status" ]; then
            swap=$(grep VmSwap "$pid/status" 2>/dev/null | awk '{print $2}')
            if [ -n "$swap" ] && [ "$swap" -gt 0 ] 2>/dev/null; then
                cmd=$(cat "$pid/comm" 2>/dev/null || echo "unknown")
                echo "  PID $(basename $pid): ${swap}kB - $cmd" >> "$OUTPUT_FILE"
            fi
        fi
    done | sort -k2 -nr | head -n 10 >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# Coleta informações de Uso de Disco (Espaço e Inodes)
echo "### Uso de Disco (Espaço) ###" >> "$OUTPUT_FILE"
df -h >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "### Uso de Disco (Inodes) ###" >> "$OUTPUT_FILE"
df -i >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Disco Detalhada
echo "### Análise Detalhada de Disco ###" >> "$OUTPUT_FILE"
echo "Dispositivos de bloco e suas partições:" >> "$OUTPUT_FILE"
lsblk -f >> "$OUTPUT_FILE" 2>&1 || echo "Comando 'lsblk' não encontrado." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Maiores diretórios em / (Top 10):" >> "$OUTPUT_FILE"
du -hx / 2>/dev/null | sort -hr | head -n 10 >> "$OUTPUT_FILE" || echo "Erro ao analisar uso de disco em /." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Arquivos maiores que 100MB:" >> "$OUTPUT_FILE"
find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -n 20 >> "$OUTPUT_FILE" || echo "Erro ao buscar arquivos grandes." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Coleta informações de Rede (Interfaces, Roteamento e Conexões)
echo "### Interfaces de Rede ###" >> "$OUTPUT_FILE"
ip a >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "### Tabela de Roteamento (route -n) ###" >> "$OUTPUT_FILE"
route -n >> "$OUTPUT_FILE" 2>&1 || echo "Comando 'route' não encontrado ou erro. Verifique se o pacote 'net-tools' está instalado." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "### Estatísticas de Rede (Top 5 Conexões Ativas com PID/Programa) ###" >> "$OUTPUT_FILE"
# Prioriza 'ss' por ser mais moderno, com fallback para 'netstat'
if command -v ss &> /dev/null; then
    ss -tunap | head -n 6 >> "$OUTPUT_FILE"
else
    netstat -tunap | head -n 6 >> "$OUTPUT_FILE" 2>&1 || echo "Comando 'netstat' ou 'ss' não encontrado. Verifique se 'iproute2' ou 'net-tools' estão instalados." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Rede Avançada
echo "### Análise de Rede Avançada ###" >> "$OUTPUT_FILE"
echo "Tabela ARP (vizinhos na rede local):" >> "$OUTPUT_FILE"
ip neigh show >> "$OUTPUT_FILE" 2>&1 || arp -a >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao obter tabela ARP." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Conexões de rede por estado:" >> "$OUTPUT_FILE"
if command -v ss &> /dev/null; then
    ss -s >> "$OUTPUT_FILE"
else
    netstat -s | grep -A 10 "Tcp:" >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao obter estatísticas de rede." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

echo "Bandwidth e estatísticas de interface:" >> "$OUTPUT_FILE"
cat /proc/net/dev >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# **NOVO**: DNS e Conectividade
echo "### Configuração DNS e Conectividade ###" >> "$OUTPUT_FILE"
echo "Servidores DNS configurados (/etc/resolv.conf):" >> "$OUTPUT_FILE"
cat /etc/resolv.conf >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao ler /etc/resolv.conf." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Teste de conectividade DNS:" >> "$OUTPUT_FILE"
nslookup google.com >> "$OUTPUT_FILE" 2>&1 || dig google.com >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao testar resolução DNS." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Gateway padrão:" >> "$OUTPUT_FILE"
ip route | grep default >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Coleta informações sobre pacotes pendentes de atualização
echo "### Pacotes Pendentes de Atualização ###" >> "$OUTPUT_FILE"
echo "NOTA: Esta seção pode exigir permissões 'sudo' para funcionar corretamente." >> "$OUTPUT_FILE"
if [ -f /etc/debian_version ]; then
    sudo apt update > /dev/null 2>&1
    apt list --upgradable >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao listar pacotes atualizáveis (apt). Verifique as permissões." >> "$OUTPUT_FILE"
elif [ -f /etc/redhat-release ]; then
    sudo yum check-update >> "$OUTPUT_FILE" 2>&1 || sudo dnf check-update >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao listar pacotes atualizáveis (yum/dnf). Verifique as permissões." >> "$OUTPUT_FILE"
else
    echo "Sistema de gerenciamento de pacotes não reconhecido (Debian/Ubuntu/RHEL/CentOS/Fedora)." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Histórico de Atualizações Recentes
echo "### Histórico de Atualizações Recentes ###" >> "$OUTPUT_FILE"
if [ -f /var/log/apt/history.log ]; then
    echo "Últimas 20 operações do APT:" >> "$OUTPUT_FILE"
    tail -n 100 /var/log/apt/history.log | grep -E "Start-Date|Install|Upgrade|Remove" | tail -n 20 >> "$OUTPUT_FILE"
elif [ -f /var/log/yum.log ]; then
    echo "Últimas 20 operações do YUM:" >> "$OUTPUT_FILE"
    tail -n 20 /var/log/yum.log >> "$OUTPUT_FILE"
elif [ -f /var/log/dnf.log ]; then
    echo "Últimas 20 operações do DNF:" >> "$OUTPUT_FILE"
    tail -n 20 /var/log/dnf.log >> "$OUTPUT_FILE"
else
    echo "Log de atualizações não encontrado." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# Coleta informações sobre o status do Firewall (se estiver ativo)
echo "### Status do Firewall (UFW/Firewalld) ###" >> "$OUTPUT_FILE"
if command -v ufw &> /dev/null; then
    ufw status verbose >> "$OUTPUT_FILE"
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --state >> "$OUTPUT_FILE"
    firewall-cmd --list-all >> "$OUTPUT_FILE"
else
    echo "Nenhum firewall comum (UFW/Firewalld) encontrado ou configurado." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Firewall Avançada
echo "### Análise de Firewall Avançada ###" >> "$OUTPUT_FILE"
echo "Regras iptables atuais:" >> "$OUTPUT_FILE"
iptables -L -n -v >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao listar regras iptables ou permissão negada." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Tabela NAT do iptables:" >> "$OUTPUT_FILE"
iptables -t nat -L -n -v >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao listar tabela NAT ou permissão negada." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Coleta informações sobre serviços em execução (Top 5 por status)
echo "### Serviços em Execução (Top 5) ###" >> "$OUTPUT_FILE"
systemctl list-units --type=service --state=running | head -n 7 >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Serviços Detalhada
echo "### Análise de Serviços Detalhada ###" >> "$OUTPUT_FILE"
echo "Serviços habilitados para inicialização:" >> "$OUTPUT_FILE"
systemctl list-unit-files --type=service --state=enabled | head -n 20 >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Serviços com falha:" >> "$OUTPUT_FILE"
systemctl list-units --type=service --state=failed >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Tempo de inicialização dos serviços:" >> "$OUTPUT_FILE"
systemd-analyze blame | head -n 15 >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao obter tempo de inicialização dos serviços." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Coleta informações sobre usuários logados
echo "### Usuários Logados Atualmente ###" >> "$OUTPUT_FILE"
who >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Usuários e Sessões
echo "### Análise de Usuários e Sessões ###" >> "$OUTPUT_FILE"
echo "Usuários com shell de login:" >> "$OUTPUT_FILE"
grep -E "/bin/bash|/bin/sh|/bin/zsh|/bin/fish" /etc/passwd >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Últimas tentativas de login (últimos 50):" >> "$OUTPUT_FILE"
lastb -n 50 >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao acessar log de tentativas de login falhadas." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Usuários bloqueados (pam_tally2 ou faillock):" >> "$OUTPUT_FILE"
if command -v pam_tally2 &> /dev/null; then
    pam_tally2 --user root >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao verificar bloqueios com pam_tally2." >> "$OUTPUT_FILE"
elif command -v faillock &> /dev/null; then
    faillock --user root >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao verificar bloqueios com faillock." >> "$OUTPUT_FILE"
else
    echo "Nenhuma ferramenta de bloqueio de usuário encontrada." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# Coleta informações de I/O de Disco (iostat)
echo "### Estatísticas de I/O de Disco (iostat -x 5 -c 2) ###" >> "$OUTPUT_FILE"
echo "NOTA: Requer o pacote 'sysstat' instalado. Coleta dados por 5 segundos, 2 vezes." >> "$OUTPUT_FILE"
if command -v iostat &> /dev/null; then
    iostat -x 5 2 >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao executar 'iostat'. Verifique as permissões ou a integridade do comando." >> "$OUTPUT_FILE"
else
    echo "Comando 'iostat' não encontrado. Instale o pacote 'sysstat' para obter estas informações (ex: 'sudo apt install sysstat' ou 'sudo yum install sysstat')." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Performance de Disco
echo "### Análise de Performance de Disco ###" >> "$OUTPUT_FILE"
echo "Dispositivos de bloco e suas estatísticas:" >> "$OUTPUT_FILE"
cat /proc/diskstats | awk '{if ($4>0) print $3, "reads:", $4, "writes:", $8}' >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Informações de montagem com opções:" >> "$OUTPUT_FILE"
mount -l >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Coleta informações sobre a tabela de sistemas de arquivos (fstab)
echo "### Tabela de Sistemas de Arquivos (/etc/fstab) ###" >> "$OUTPUT_FILE"
if [ -f /etc/fstab ]; then
    cat /etc/fstab >> "$OUTPUT_FILE"
else
    echo "/etc/fstab não encontrado." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# Coleta informações detalhadas de processos (ps faux)
echo "### Processos em Execução (ps faux - Visão Detalhada) ###" >> "$OUTPUT_FILE"
ps faux >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Processos Avançada
echo "### Análise de Processos Avançada ###" >> "$OUTPUT_FILE"
echo "Processos zumbis:" >> "$OUTPUT_FILE"
ps aux | awk '$8 ~ /^Z/ { print $2, $11 }' >> "$OUTPUT_FILE" || echo "Nenhum processo zumbi encontrado." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Processos com maior uso de file descriptors:" >> "$OUTPUT_FILE"
for pid in /proc/[0-9]*; do
    if [ -d "$pid/fd" ]; then
        fd_count=$(ls "$pid/fd" 2>/dev/null | wc -l)
        if [ "$fd_count" -gt 100 ] 2>/dev/null; then
            cmd=$(cat "$pid/comm" 2>/dev/null || echo "unknown")
            echo "  PID $(basename $pid): $fd_count FDs - $cmd" >> "$OUTPUT_FILE"
        fi
    fi
done | sort -k3 -nr | head -n 10 >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Coleta as últimas 150 linhas do log do kernel (dmesg)
echo "### Últimas 150 Linhas do Log do Kernel (dmesg) ###" >> "$OUTPUT_FILE"
dmesg | tail -n 150 >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Kernel e Módulos
echo "### Análise de Kernel e Módulos ###" >> "$OUTPUT_FILE"
echo "Módulos carregados (Top 20):" >> "$OUTPUT_FILE"
lsmod | head -n 21 >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Parâmetros do kernel:" >> "$OUTPUT_FILE"
sysctl -a 2>/dev/null | grep -E "vm\.|net\.|kernel\." | head -n 30 >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Informações de hardware (lshw - resumo):" >> "$OUTPUT_FILE"
if command -v lshw &> /dev/null; then
    lshw -short >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao executar lshw." >> "$OUTPUT_FILE"
else
    echo "Comando 'lshw' não encontrado. Instale para obter informações detalhadas de hardware." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

echo "----------------------------------------------------------------------------------" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# --- Seção 2: Análise Detalhada de /var/log ---
echo "## SEÇÃO 2: ANÁLISE DETALHADA DO DIRETÓRIO /VAR/LOG" >> "$OUTPUT_FILE"
echo "Esta seção foca na estrutura e conteúdo dos arquivos de log, crucial para identificar eventos e problemas específicos." >> "$OUTPUT_FILE"
echo "----------------------------------------------------------------------------------" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# --- 4GB USAGE CHECK for /var/log ---
CURRENT_USAGE_OUTPUT=$(du -sh "$LOG_DIR" 2>/dev/null)
CURRENT_USAGE_SIZE=$(echo "$CURRENT_USAGE_OUTPUT" | awk '{print $1}')
CURRENT_USAGE_UNIT=$(echo "$CURRENT_USAGE_OUTPUT" | sed 's/[0-9.]//g')
CURRENT_USAGE_RAW=$(echo "$CURRENT_USAGE_SIZE" | sed 's/[A-Za-z]//g')

CURRENT_USAGE_MB=0
if [[ "$CURRENT_USAGE_UNIT" == "G" ]]; then
    CURRENT_USAGE_MB=$(echo "$CURRENT_USAGE_RAW * 1024" | bc)
elif [[ "$CURRENT_USAGE_UNIT" == "M" ]]; then
    CURRENT_USAGE_MB=$(echo "$CURRENT_USAGE_RAW" | bc)
elif [[ "$CURRENT_USAGE_UNIT" == "K" ]]; then
    CURRENT_USAGE_MB=$(echo "scale=2; $CURRENT_USAGE_RAW / 1024" | bc)
fi

MAX_ALLOWED_MB=4096 # 4GB em MB

echo "INFO: Verificando o uso de disco de $LOG_DIR..." >> "$OUTPUT_FILE"
echo "INFO: Uso atual de $LOG_DIR: $CURRENT_USAGE_SIZE" >> "$OUTPUT_FILE"

if (( $(echo "$CURRENT_USAGE_MB >= $MAX_ALLOWED_MB" | bc -l) )); then
    echo "WARNING: O uso de $LOG_DIR ($CURRENT_USAGE_SIZE) é igual ou maior que 4GB. O script não prosseguirá com a extração detalhada de conteúdo de log para evitar um relatório excessivamente grande." | tee -a "$OUTPUT_FILE"
    echo "--- ANÁLISE DE LOGS ABORTADA DEVIDO AO LIMITE DE TAMANHO ---" >> "$OUTPUT_FILE"
    echo "--- FIM DO RELATÓRIO DE ANÁLISE ABRANGENTE DO SERVIDOR LINUX ---" >> "$OUTPUT_FILE"
    exit 1
else
    echo "INFO: O uso de $LOG_DIR ($CURRENT_USAGE_SIZE) está abaixo de 4GB. Prosseguindo com a análise detalhada de logs." >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "----------------------------------------------------------------------------------" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Função para obter permissões em formato simbólico e descritivo
get_permissions_and_description() {
    local perm_symbolic=$(stat -c "%A" "$1" 2>/dev/null)
    if [ -z "$perm_symbolic" ]; then
        echo "N/A (Erro ao obter permissões)"
        return
    fi

    local perm_octal=$(stat -c "%a" "$1" 2>/dev/null)
    local owner_perm=""
    local group_perm=""
    local others_perm=""

    convert_octal_to_desc() {
        case "$1" in
            0) echo "nenhuma" ;;
            1) echo "executar" ;;
            2) echo "escrever" ;;
            3) echo "escrever/executar" ;;
            4) echo "ler" ;;
            5) echo "ler/executar" ;;
            6) echo "ler/escrever" ;;
            7) echo "ler/escrever/executar" ;;
            *) echo "desconhecido" ;;
        esac
    }

    owner_perm=$(convert_octal_to_desc "${perm_octal:0:1}")
    group_perm=$(convert_octal_to_desc "${perm_octal:1:1}")
    others_perm=$(convert_octal_to_desc "${perm_octal:2:1}")

    echo "$perm_symbolic (Proprietário: $owner_perm, Grupo: $group_perm, Outros: $others_perm)"
}

# --- SUB-SEÇÃO 2.1: VISÃO GERAL DA ESTRUTURA DE DIRETÓRIOS E ARQUIVOS COM PERMISSÕES ---
echo "### SUB-SEÇÃO 2.1: VISÃO GERAL DA ESTRUTURA DE DIRETÓRIOS E ARQUIVOS COM PERMISSÕES ###" >> "$OUTPUT_FILE"
echo "Esta sub-seção fornece uma visão hierárquica completa do diretório $LOG_DIR, incluindo subdiretórios e arquivos, juntamente com suas permissões UNIX. Isso ajuda a entender o layout do sistema de arquivos antes de analisar o conteúdo dos logs." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Função recursiva para listar diretórios e arquivos (Sub-seção 2.1)
list_recursive() {
    local current_path="$1"
    local indent="$2"

    if [ ! -r "$current_path" ] && [ ! -d "$current_path" ]; then
        echo "${indent}[Pulando entrada ilegível ou inacessível: $current_path]" >> "$OUTPUT_FILE"
        return
    fi

    for entry in "$current_path"/*; do
        if [ ! -e "$entry" ]; then
            echo "${indent}[Pulando entrada inexistente (ex: link simbólico quebrado): $(basename "$entry")]" >> "$OUTPUT_FILE"
            continue
        fi

        if [ -d "$entry" ]; then
            echo "${indent}### DIRETÓRIO: $(basename "$entry")/" >> "$OUTPUT_FILE"
            echo "${indent}  CAMINHO COMPLETO: $entry" >> "$OUTPUT_FILE"
            echo "${indent}  TIPO: Diretório" >> "$OUTPUT_FILE"
            echo "${indent}  SUB-ENTRADAS:" >> "$OUTPUT_FILE"
            list_recursive "$entry" "$indent  "
            echo "" >> "$OUTPUT_FILE"
        elif [ -f "$entry" ]; then
            local permissions_info=$(get_permissions_and_description "$entry")
            echo "${indent}### ARQUIVO: $(basename "$entry")" >> "$OUTPUT_FILE"
            echo "${indent}  CAMINHO COMPLETO: $entry" >> "$OUTPUT_FILE"
            echo "${indent}  TIPO: Arquivo" >> "$OUTPUT_FILE"
            echo "${indent}  PERMISSÕES: $permissions_info" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
    done
}

# Inicia a listagem recursiva a partir de /var/log para a Sub-seção 2.1
list_recursive "$LOG_DIR" ""

echo "----------------------------------------------------------------------------------" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# --- SUB-SEÇÃO 2.2: CONTEÚDO DE ARQUIVOS DE LOG INDIVIDUAIS ---
echo "### SUB-SEÇÃO 2.2: CONTEÚDO DE ARQUIVOS DE LOG INDIVIDUAIS ###" >> "$OUTPUT_FILE"
echo "Esta sub-seção detalha o conteúdo dos arquivos de log relevantes encontrados em $LOG_DIR. Para cada arquivo, você encontrará seu caminho completo, permissões UNIX e as últimas $MAX_LOG_LINES linhas de seu conteúdo. Isso permite uma análise aprofundada da atividade recente, erros e eventos do sistema." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Função para processar o conteúdo do arquivo (Sub-seção 2.2)
process_file_content() {
    local file_path="$1"

    if [ ! -r "$file_path" ]; then
        echo "### ARQUIVO DE LOG: $file_path" >> "$OUTPUT_FILE"
        echo "  STATUS: ILEGÍVEL (Permissão Negada ou arquivo desapareceu)" >> "$OUTPUT_FILE"
        echo "  --- FIM DO CONTEÚDO PARA $file_path ---" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        return
    fi

    local permissions_info=$(get_permissions_and_description "$file_path")
    local file_size_mb=$(du -sh "$file_path" 2>/dev/null | awk '{print $1}')
    local modified_time=$(stat -c "%y" "$file_path" 2>/dev/null)

    echo "### ARQUIVO DE LOG: $file_path" >> "$OUTPUT_FILE"
    echo "  PERMISSÕES: $permissions_info" >> "$OUTPUT_FILE"
    echo "  TAMANHO: ${file_size_mb:-N/A}" >> "$OUTPUT_FILE"
    echo "  MODIFICADO: ${modified_time:-N/A}" >> "$OUTPUT_FILE"
    echo "  ÚLTIMAS $MAX_LOG_LINES LINHAS DE CONTEÚDO:" >> "$OUTPUT_FILE"

    local tmp_content_file="/tmp/temp_log_content_$$"

    case "$(file -b --mime-type "$file_path" 2>/dev/null)" in
        text/* | application/x-empty | inode/x-empty)
            tail -n "$MAX_LOG_LINES" "$file_path" 2>/dev/null >> "$OUTPUT_FILE" || echo "    [ERRO: Falha ao ler conteúdo para $file_path - verifique a integridade do arquivo.]" >> "$OUTPUT_FILE"
            ;;
        application/gzip)
            gunzip -c "$file_path" 2>/dev/null | tail -n "$MAX_LOG_LINES" >> "$OUTPUT_FILE" || echo "    [ERRO: Falha ao descompactar/ler conteúdo gzip para $file_path.]" >> "$OUTPUT_FILE"
            ;;
        application/x-bzip2)
            bunzip2 -c "$file_path" 2>/dev/null | tail -n "$MAX_LOG_LINES" >> "$OUTPUT_FILE" || echo "    [ERRO: Falha ao descompactar/ler conteúdo bzip2 para $file_path.]" >> "$OUTPUT_FILE"
            ;;
        application/x-xz)
            xzcat "$file_path" 2>/dev/null | tail -n "$MAX_LOG_LINES" >> "$OUTPUT_FILE" || echo "    [ERRO: Falha ao descompactar/ler conteúdo xz para $file_path.]" >> "$OUTPUT_FILE"
            ;;
        application/zip)
            unzip -p "$file_path" > "$tmp_content_file" 2>/dev/null
            if [ -s "$tmp_content_file" ]; then
                tail -n "$MAX_LOG_LINES" "$tmp_content_file" >> "$OUTPUT_FILE"
            else
                echo "    [AVISO: Arquivo ZIP ($file_path) pode não conter conteúdo de texto ou a extração falhou.]" >> "$OUTPUT_FILE"
            fi
            ;;
        application/x-tar)
            echo "    [Conteúdo do arquivo TAR ($file_path) é um arquivo de arquivos. Listando estrutura interna:]" >> "$OUTPUT_FILE"
            tar -tf "$file_path" 2>/dev/null >> "$OUTPUT_FILE" || echo "    [ERRO: Falha ao listar conteúdo do arquivo TAR $file_path.]" >> "$OUTPUT_FILE"
            ;;
        application/x-rar)
            echo "    [AVISO: Arquivo RAR ($file_path) detectado. O conteúdo não pode ser extraído automaticamente sem o utilitário 'unrar' (instale se necessário, depois execute o script novamente).]" >> "$OUTPUT_FILE"
            ;;
        *)
            echo "    [Conteúdo não pode ser exibido para este tipo de arquivo ou não é baseado em texto: $file_path]" >> "$OUTPUT_FILE"
            ;;
    esac

    rm -f "$tmp_content_file"

    echo "--- FIM DO CONTEÚDO PARA $file_path ---" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
}

declare -a FILES_TO_PROCESS

collect_files_recursive() {
    local current_path="$1"
    for entry in "$current_path"/*; do
        if [ ! -e "$entry" ]; then
            continue
        fi

        if [ -d "$entry" ]; then
            collect_files_recursive "$entry"
        elif [ -f "$entry" ]; then
            FILES_TO_PROCESS+=("$entry")
        fi
    done
}

collect_files_recursive "$LOG_DIR"

for file_path in "${FILES_TO_PROCESS[@]}"; do
    process_file_content "$file_path"
done

# --- SUB-SEÇÃO 2.3: ANÁLISE DE EVENTOS CRÍTICOS EM LOGS ---
echo "### SUB-SEÇÃO 2.3: ANÁLISE DE EVENTOS CRÍTICOS EM LOGS ###" >> "$OUTPUT_FILE"
echo "Esta sub-seção busca por padrões de eventos críticos em arquivos de log comuns, como tentativas de login falhas, erros do sistema e avisos." >> "$OUTPUT_FILE"
echo "----------------------------------------------------------------------------------" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Análise de auth.log (ou equivalente) para eventos de segurança
echo "#### Eventos de Segurança (auth.log/secure) ####" >> "$OUTPUT_FILE"
if [ -f /var/log/auth.log ]; then
    echo "Últimas 50 linhas de /var/log/auth.log com falhas/sucessos de autenticação:" >> "$OUTPUT_FILE"
    grep -E "Failed password|authentication failure|Accepted publickey" "/var/log/auth.log" | tail -n 50 >> "$OUTPUT_FILE" || echo "  Nenhum evento de segurança recente ou erro ao ler /var/log/auth.log." >> "$OUTPUT_FILE"
elif [ -f /var/log/secure ]; then
    echo "Últimas 50 linhas de /var/log/secure com falhas/sucessos de autenticação:" >> "$OUTPUT_FILE"
    grep -E "Failed password|authentication failure|Accepted publickey" "/var/log/secure" | tail -n 50 >> "$OUTPUT_FILE" || echo "  Nenhum evento de segurança recente ou erro ao ler /var/log/secure." >> "$OUTPUT_FILE"
else
    echo "  Arquivos de log de autenticação (auth.log ou secure) não encontrados." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Segurança Avançada
echo "#### Análise de Segurança Avançada ####" >> "$OUTPUT_FILE"
echo "IPs com mais tentativas de login falhadas:" >> "$OUTPUT_FILE"
if [ -f /var/log/auth.log ]; then
    grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | head -n 10 >> "$OUTPUT_FILE" || echo "  Erro ao analisar IPs com falhas de login." >> "$OUTPUT_FILE"
elif [ -f /var/log/secure ]; then
    grep "Failed password" /var/log/secure | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | head -n 10 >> "$OUTPUT_FILE" || echo "  Erro ao analisar IPs com falhas de login." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

echo "Usuários com mais tentativas de login falhadas:" >> "$OUTPUT_FILE"
if [ -f /var/log/auth.log ]; then
    grep "Failed password for" /var/log/auth.log | awk '{print $9}' | sort | uniq -c | sort -nr | head -n 10 >> "$OUTPUT_FILE" || echo "  Erro ao analisar usuários com falhas de login." >> "$OUTPUT_FILE"
elif [ -f /var/log/secure ]; then
    grep "Failed password for" /var/log/secure | awk '{print $9}' | sort | uniq -c | sort -nr | head -n 10 >> "$OUTPUT_FILE" || echo "  Erro ao analisar usuários com falhas de login." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# Análise de syslog/messages para erros gerais do sistema
echo "#### Erros e Avisos do Sistema (syslog/messages) ####" >> "$OUTPUT_FILE"
if [ -f /var/log/syslog ]; then
    echo "Últimas 50 linhas de /var/log/syslog com erros/avisos:" >> "$OUTPUT_FILE"
    grep -E "error|fail|warning|panic" "/var/log/syslog" | tail -n 50 >> "$OUTPUT_FILE" || echo "  Nenhum erro/aviso recente ou erro ao ler /var/log/syslog." >> "$OUTPUT_FILE"
elif [ -f /var/log/messages ]; then
    echo "Últimas 50 linhas de /var/log/messages com erros/avisos:" >> "$OUTPUT_FILE"
    grep -E "error|fail|warning|panic" "/var/log/messages" | tail -n 50 >> "$OUTPUT_FILE" || echo "  Nenhum erro/aviso recente ou erro ao ler /var/log/messages." >> "$OUTPUT_FILE"
else
    echo "  Arquivos de log do sistema (syslog ou messages) não encontrados." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Logs do Sistema Avançada
echo "#### Análise de Logs do Sistema Avançada ####" >> "$OUTPUT_FILE"
echo "Erros mais frequentes no sistema:" >> "$OUTPUT_FILE"
if [ -f /var/log/syslog ]; then
    grep -i error /var/log/syslog | awk '{for(i=5;i<=NF;i++) printf "%s ", $i; print ""}' | sort | uniq -c | sort -nr | head -n 10 >> "$OUTPUT_FILE" || echo "  Erro ao analisar erros frequentes." >> "$OUTPUT_FILE"
elif [ -f /var/log/messages ]; then
    grep -i error /var/log/messages | awk '{for(i=5;i<=NF;i++) printf "%s ", $i; print ""}' | sort | uniq -c | sort -nr | head -n 10 >> "$OUTPUT_FILE" || echo "  Erro ao analisar erros frequentes." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

echo "Serviços que mais geram logs:" >> "$OUTPUT_FILE"
if [ -f /var/log/syslog ]; then
    awk '{print $5}' /var/log/syslog | cut -d'[' -f1 | sort | uniq -c | sort -nr | head -n 15 >> "$OUTPUT_FILE" || echo "  Erro ao analisar serviços que geram logs." >> "$OUTPUT_FILE"
elif [ -f /var/log/messages ]; then
    awk '{print $5}' /var/log/messages | cut -d'[' -f1 | sort | uniq -c | sort -nr | head -n 15 >> "$OUTPUT_FILE" || echo "  Erro ao analisar serviços que geram logs." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# Análise de logs de aplicativos comuns (ex: Apache, Nginx)
echo "#### Erros em Logs de Aplicativos Comuns ####" >> "$OUTPUT_FILE"
# Apache
if [ -f /var/log/apache2/error.log ]; then
    echo "Últimas 50 linhas de /var/log/apache2/error.log:" >> "$OUTPUT_FILE"
    tail -n 50 /var/log/apache2/error.log >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao ler /var/log/apache2/error.log." >> "$OUTPUT_FILE"
elif [ -f /var/log/httpd/error_log ]; then
    echo "Últimas 50 linhas de /var/log/httpd/error_log:" >> "$OUTPUT_FILE"
    tail -n 50 /var/log/httpd/error_log >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao ler /var/log/httpd/error_log." >> "$OUTPUT_FILE"
else
    echo "  Log de erro do Apache não encontrado." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# Nginx
if [ -f /var/log/nginx/error.log ]; then
    echo "Últimas 50 linhas de /var/log/nginx/error.log:" >> "$OUTPUT_FILE"
    tail -n 50 /var/log/nginx/error.log >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao ler /var/log/nginx/error.log." >> "$OUTPUT_FILE"
else
    echo "  Log de erro do Nginx não encontrado." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Logs de Aplicação Avançada
echo "#### Análise de Logs de Aplicação Avançada ####" >> "$OUTPUT_FILE"

# MySQL/MariaDB
if [ -f /var/log/mysql/error.log ]; then
    echo "Últimas 30 linhas do log de erro do MySQL:" >> "$OUTPUT_FILE"
    tail -n 30 /var/log/mysql/error.log >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao ler log do MySQL." >> "$OUTPUT_FILE"
elif [ -f /var/log/mysqld.log ]; then
    echo "Últimas 30 linhas do log de erro do MySQL:" >> "$OUTPUT_FILE"
    tail -n 30 /var/log/mysqld.log >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao ler log do MySQL." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# PostgreSQL
if [ -f /var/log/postgresql/postgresql*.log ]; then
    echo "Últimas 30 linhas do log do PostgreSQL:" >> "$OUTPUT_FILE"
    tail -n 30 /var/log/postgresql/postgresql*.log >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao ler log do PostgreSQL." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# Docker
if [ -f /var/log/docker.log ]; then
    echo "Últimas 30 linhas do log do Docker:" >> "$OUTPUT_FILE"
    tail -n 30 /var/log/docker.log >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao ler log do Docker." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

echo "----------------------------------------------------------------------------------" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# --- Seção 3: Informações Adicionais do Sistema ---
echo "## SEÇÃO 3: INFORMAÇÕES ADICIONAIS DO SISTEMA" >> "$OUTPUT_FILE"
echo "Esta seção inclui detalhes sobre a identificação do sistema, status de serviços, estatísticas de rede e tarefas agendadas." >> "$OUTPUT_FILE"
echo "----------------------------------------------------------------------------------" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Informações de Identificação do Sistema
echo "### Identificação do Sistema ###" >> "$OUTPUT_FILE"
echo "Hostname e OS (hostnamectl):" >> "$OUTPUT_FILE"
hostnamectl >> "$OUTPUT_FILE" 2>&1 || echo "Comando 'hostnamectl' não encontrado." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Distribuição (lsb_release -a):" >> "$OUTPUT_FILE"
lsb_release -a >> "$OUTPUT_FILE" 2>&1 || echo "Comando 'lsb_release' não encontrado. Instale o pacote 'lsb-release'." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Versão do Kernel (uname -a):" >> "$OUTPUT_FILE"
uname -a >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Informações Avançadas do Sistema
echo "### Informações Avançadas do Sistema ###" >> "$OUTPUT_FILE"
echo "Timezone configurado:" >> "$OUTPUT_FILE"
timedatectl >> "$OUTPUT_FILE" 2>&1 || echo "Comando 'timedatectl' não encontrado." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Localização e idioma:" >> "$OUTPUT_FILE"
locale >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Variáveis de ambiente importantes:" >> "$OUTPUT_FILE"
env | grep -E "PATH|HOME|USER|SHELL|LANG|TZ" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Detalhes de CPU e Memória
echo "### Detalhes de CPU e Memória ###" >> "$OUTPUT_FILE"
echo "Modelo da CPU:" >> "$OUTPUT_FILE"
cat /proc/cpuinfo | grep 'model name' | uniq >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Informações Detalhadas de Memória (/proc/meminfo):" >> "$OUTPUT_FILE"
cat /proc/meminfo | grep -E 'MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree' >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Hardware Detalhada
echo "### Análise de Hardware Detalhada ###" >> "$OUTPUT_FILE"
echo "Informações de CPU detalhadas:" >> "$OUTPUT_FILE"
lscpu >> "$OUTPUT_FILE" 2>&1 || echo "Comando 'lscpu' não encontrado." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Dispositivos PCI:" >> "$OUTPUT_FILE"
lspci >> "$OUTPUT_FILE" 2>&1 || echo "Comando 'lspci' não encontrado." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Dispositivos USB:" >> "$OUTPUT_FILE"
lsusb >> "$OUTPUT_FILE" 2>&1 || echo "Comando 'lsusb' não encontrado." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Informações de DMI/SMBIOS:" >> "$OUTPUT_FILE"
dmidecode -t system >> "$OUTPUT_FILE" 2>&1 || echo "Comando 'dmidecode' não encontrado ou requer privilégios root." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Estatísticas de Memória Virtual e CPU (vmstat)
echo "### Estatísticas de Memória Virtual e CPU (vmstat 5 2) ###" >> "$OUTPUT_FILE"
echo "NOTA: Coleta dados por 5 segundos, 2 vezes. Requer o pacote 'sysstat' instalado." >> "$OUTPUT_FILE"
if command -v vmstat &> /dev/null; then
    vmstat 5 2 >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao executar 'vmstat'. Verifique as permissões ou a integridade do comando." >> "$OUTPUT_FILE"
else
    echo "Comando 'vmstat' não encontrado. Instale o pacote 'sysstat' para obter estas informações (ex: 'sudo apt install sysstat' ou 'sudo yum install sysstat')." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# Serviços com Falha
echo "### Serviços do Systemd com Falha ###" >> "$OUTPUT_FILE"
systemctl --failed >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Status de Serviços Comuns
echo "### Status de Serviços Comuns (Web, Banco de Dados, Contêineres) ###" >> "$OUTPUT_FILE"
echo "NOTA: Esta seção verifica o status de serviços comuns. 'Ativo e Rodando' indica que o serviço está em execução." >> "$OUTPUT_FILE"
for service in apache2 nginx mysql postgresql docker sshd; do
    echo "  Verificando serviço: $service" >> "$OUTPUT_FILE"
    if systemctl is-active --quiet "$service"; then
        echo "    $service: Ativo e Rodando" >> "$OUTPUT_FILE"
        echo "    Últimas 5 linhas do status de $service:" >> "$OUTPUT_FILE"
        systemctl status "$service" | head -n 5 >> "$OUTPUT_FILE" 2>&1 || echo "      Erro ao obter status detalhado para $service." >> "$OUTPUT_FILE"
    else
        echo "    $service: Inativo ou Não Encontrado" >> "$OUTPUT_FILE"
    fi
    echo "" >> "$OUTPUT_FILE"
done
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Contêineres
echo "### Análise de Contêineres ###" >> "$OUTPUT_FILE"
if command -v docker &> /dev/null; then
    echo "Contêineres Docker em execução:" >> "$OUTPUT_FILE"
    docker ps >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao listar contêineres Docker." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    echo "Imagens Docker:" >> "$OUTPUT_FILE"
    docker images >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao listar imagens Docker." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    echo "Uso de espaço do Docker:" >> "$OUTPUT_FILE"
    docker system df >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao obter uso de espaço do Docker." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

if command -v podman &> /dev/null; then
    echo "Contêineres Podman em execução:" >> "$OUTPUT_FILE"
    podman ps >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao listar contêineres Podman." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

# Estatísticas de Rede Detalhadas (erros/drops)
echo "### Estatísticas Detalhadas de Interfaces de Rede (ip -s link show) ###" >> "$OUTPUT_FILE"
ip -s link show >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Portas de Escuta Ativas
echo "### Portas de Escuta Ativas (ss -tulnp) ###" >> "$OUTPUT_FILE"
echo "Esta seção lista todas as portas TCP e UDP que estão em estado de escuta, juntamente com o processo e PID associados." >> "$OUTPUT_FILE"
if command -v ss &> /dev/null; then
    ss -tulnp >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao listar portas de escuta com 'ss'. Verifique as permissões ou a instalação do 'iproute2'." >> "$OUTPUT_FILE"
else
    netstat -tulnp >> "$OUTPUT_FILE" 2>&1 || echo "Comando 'netstat' ou 'ss' não encontrado. Verifique se 'iproute2' ou 'net-tools' estão instalados." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# Pontos de Montagem
echo "### Pontos de Montagem Atuais (mount) ###" >> "$OUTPUT_FILE"
mount >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Últimos Logins
echo "### Últimos 20 Logins (last -n 20) ###" >> "$OUTPUT_FILE"
last -n 20 >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Tarefas Agendadas (Cron)
echo "### Tarefas Agendadas (Cron) ###" >> "$OUTPUT_FILE"
echo "NOTA: 'crontab -l' mostra apenas o crontab do usuário que executa o script." >> "$OUTPUT_FILE"
echo "Crontab do Usuário Atual:" >> "$OUTPUT_FILE"
crontab -l >> "$OUTPUT_FILE" 2>&1 || echo "Nenhum crontab para o usuário atual ou erro de permissão." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Crontabs do Sistema (/etc/cron.*):" >> "$OUTPUT_FILE"
ls -l /etc/cron.* >> "$OUTPUT_FILE"
if [ -d "/etc/cron.d" ]; then
    echo "Conteúdo de /etc/cron.d/:" >> "$OUTPUT_FILE"
    ls -l /etc/cron.d/ >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Tarefas Agendadas Avançada
echo "### Análise de Tarefas Agendadas Avançada ###" >> "$OUTPUT_FILE"
echo "Tarefas systemd timers:" >> "$OUTPUT_FILE"
systemctl list-timers >> "$OUTPUT_FILE" 2>&1 || echo "Erro ao listar timers do systemd." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Tarefas at agendadas:" >> "$OUTPUT_FILE"
atq >> "$OUTPUT_FILE" 2>&1 || echo "Comando 'atq' não encontrado ou nenhuma tarefa agendada." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# --- SUB-SEÇÃO 3.1: INFORMAÇÕES DE SEGURANÇA DO SISTEMA ---
echo "### SUB-SEÇÃO 3.1: INFORMAÇÕES DE SEGURANÇA DO SISTEMA ###" >> "$OUTPUT_FILE"
echo "Esta sub-seção detalha configurações e status relacionados à segurança do servidor." >> "$OUTPUT_FILE"
echo "----------------------------------------------------------------------------------" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Usuários com UID 0 (root)
echo "#### Usuários com UID 0 (Root) ####" >> "$OUTPUT_FILE"
awk -F: '($3 == 0) {print $1}' /etc/passwd >> "$OUTPUT_FILE" || echo "  Erro ao ler /etc/passwd." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Membros do grupo sudo (ou wheel)
echo "#### Membros do Grupo 'sudo' ou 'wheel' ####" >> "$OUTPUT_FILE"
if grep -q "^sudo:" /etc/group; then
    echo "  Grupo 'sudo':" >> "$OUTPUT_FILE"
    grep "^sudo:" /etc/group | cut -d: -f4 >> "$OUTPUT_FILE" || echo "    Erro ao listar membros do grupo 'sudo'." >> "$OUTPUT_FILE"
fi
if grep -q "^wheel:" /etc/group; then
    echo "  Grupo 'wheel':" >> "$OUTPUT_FILE"
    grep "^wheel:" /etc/group | cut -d: -f4 >> "$OUTPUT_FILE" || echo "    Erro ao listar membros do grupo 'wheel'." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Usuários Avançada
echo "#### Análise de Usuários Avançada ####" >> "$OUTPUT_FILE"
echo "Usuários com senhas vazias:" >> "$OUTPUT_FILE"
awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null >> "$OUTPUT_FILE" || echo "  Erro ao acessar /etc/shadow ou nenhum usuário com senha vazia." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Usuários com shell válido:" >> "$OUTPUT_FILE"
grep -E "/bin/bash|/bin/sh|/bin/zsh|/bin/fish" /etc/passwd | cut -d: -f1 >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Contas de usuário criadas recentemente (últimos 30 dias):" >> "$OUTPUT_FILE"
find /home -maxdepth 1 -type d -mtime -30 -exec basename {} \; 2>/dev/null | grep -v "^home$" >> "$OUTPUT_FILE" || echo "  Nenhuma conta nova encontrada ou erro de acesso." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Configuração do Servidor SSH
echo "#### Configuração do Servidor SSH (/etc/ssh/sshd_config) ####" >> "$OUTPUT_FILE"
if [ -f /etc/ssh/sshd_config ]; then
    echo "  Verificando configurações importantes:" >> "$OUTPUT_FILE"
    grep -E "^Port|^PermitRootLogin|^PasswordAuthentication|^ChallengeResponseAuthentication|^UsePAM|^AllowUsers|^DenyUsers|^AllowGroups|^DenyGroups" /etc/ssh/sshd_config | grep -v "#" | sed 's/^[[:space:]]*//' >> "$OUTPUT_FILE"
    if ! grep -q "^PermitRootLogin[[:space:]]*no" /etc/ssh/sshd_config; then
        echo "  AVISO: PermitRootLogin pode estar ativado ou não configurado para 'no'. Isso é um risco de segurança." >> "$OUTPUT_FILE"
    fi
    if grep -q "^PasswordAuthentication[[:space:]]*yes" /etc/ssh/sshd_config; then
        echo "  AVISO: PasswordAuthentication está ativado. Considere desativar se usar autenticação por chave SSH." >> "$OUTPUT_FILE"
    fi
else
    echo "  /etc/ssh/sshd_config não encontrado." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Segurança SSH Avançada
echo "#### Análise de Segurança SSH Avançada ####" >> "$OUTPUT_FILE"
echo "Chaves SSH autorizadas para usuários:" >> "$OUTPUT_FILE"
for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        user=$(basename "$user_home")
        if [ -f "$user_home/.ssh/authorized_keys" ]; then
            echo "  Usuário $user tem $(wc -l < "$user_home/.ssh/authorized_keys") chave(s) autorizada(s)" >> "$OUTPUT_FILE"
        fi
    fi
done
if [ -f /root/.ssh/authorized_keys ]; then
    echo "  Usuário root tem $(wc -l < /root/.ssh/authorized_keys) chave(s) autorizada(s)" >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

echo "Conexões SSH ativas:" >> "$OUTPUT_FILE"
who | grep pts >> "$OUTPUT_FILE" || echo "  Nenhuma conexão SSH ativa encontrada." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Validação Específica para Servidores "dinesh"
if hostname | grep -q "dinesh"; then
    echo "### Servidor dinesh, consumo de CPU por user FTP ###" >> "$OUTPUT_FILE"
    echo "NOTA: Esta análise tenta identificar o consumo de CPU por usuários locais, incluindo potenciais usuários FTP." >> "$OUTPUT_FILE"
    # O ls /home/ | tr '\n' '|' cria uma regex como "user1|user2|user3" para grep
    ps -eo user,%cpu,%mem --sort=-%cpu | awk '{arr[$1]+=$2} END {for (i in arr) print i, arr[i]}' | grep -E "$(ls /home/ 2>/dev/null | tr '\n' '|' | sed 's/|$//')" | grep -wv '0' >> "$OUTPUT_FILE" 2>&1 || echo "Não foi possível coletar dados de consumo de CPU por usuário ou nenhum usuário com consumo significativo." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

# **NOVO**: Análise de Processos FTP e Transferências
echo "### Análise de Processos FTP e Transferências ###" >> "$OUTPUT_FILE"
echo "Processos FTP ativos:" >> "$OUTPUT_FILE"
ps aux | grep -E "ftp|sftp|vsftpd|proftpd" | grep -v grep >> "$OUTPUT_FILE" || echo "  Nenhum processo FTP ativo encontrado." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Conexões FTP ativas:" >> "$OUTPUT_FILE"
if command -v ss &> /dev/null; then
    ss -tn | grep :21 >> "$OUTPUT_FILE" || echo "  Nenhuma conexão FTP ativa na porta 21." >> "$OUTPUT_FILE"
else
    netstat -tn | grep :21 >> "$OUTPUT_FILE" || echo "  Nenhuma conexão FTP ativa na porta 21." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# Configuração do Logrotate
echo "### Configuração do Logrotate ###" >> "$OUTPUT_FILE"
echo "Esta seção mostra as configurações globais e por aplicativo do logrotate." >> "$OUTPUT_FILE"
echo "#### Arquivo de Configuração Principal (/etc/logrotate.conf) ####" >> "$OUTPUT_FILE"
if [ -f /etc/logrotate.conf ]; then
    cat /etc/logrotate.conf >> "$OUTPUT_FILE"
else
    echo "  /etc/logrotate.conf não encontrado." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

echo "#### Configurações de Logrotate por Aplicativo (/etc/logrotate.d/) ####" >> "$OUTPUT_FILE"
if [ -d /etc/logrotate.d ]; then
    for config_file in /etc/logrotate.d/*; do
        if [ -f "$config_file" ]; then
            echo "  ##### Arquivo: $(basename "$config_file") #####" >> "$OUTPUT_FILE"
            cat "$config_file" >> "$OUTPUT_FILE" 2>&1 || echo "    Erro ao ler arquivo de configuração: $config_file" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
    done
else
    echo "  Diretório /etc/logrotate.d não encontrado." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Status do Logrotate
echo "#### Status do Logrotate ####" >> "$OUTPUT_FILE"
echo "Status do logrotate:" >> "$OUTPUT_FILE"
if [ -f /var/lib/logrotate/status ]; then
    head -n 20 /var/lib/logrotate/status >> "$OUTPUT_FILE"
else
    echo "  Arquivo de status do logrotate não encontrado." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

echo "----------------------------------------------------------------------------------" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# --- Seção 4: Análise de Armazenamento e Boot ---
echo "## SEÇÃO 4: ANÁLISE DE ARMAZENAMENTO E BOOT" >> "$OUTPUT_FILE"
echo "Esta seção fornece informações detalhadas sobre a saúde dos discos, configurações de RAID e o status do bootloader." >> "$OUTPUT_FILE"
echo "----------------------------------------------------------------------------------" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Status SMART dos Discos
echo "### Status SMART dos Discos (smartctl) ###" >> "$OUTPUT_FILE"
echo "NOTA: Requer o pacote 'smartmontools' instalado e permissões de root para acesso completo." >> "$OUTPUT_FILE"
if command -v smartctl &> /dev/null; then
    # Lista dispositivos de bloco comuns (sda, sdb, nvme0n1, vda, etc.)
    for disk in $(ls -1 /dev/sd[a-z] /dev/nvme[0-9]n[0-9] /dev/vd[a-z] 2>/dev/null); do
        if [ -b "$disk" ]; then # Verifica se é um dispositivo de bloco
            echo "  Verificando $disk:" >> "$OUTPUT_FILE"
            # -H: Health Self-Assessment Test
            sudo smartctl -H "$disk" >> "$OUTPUT_FILE" 2>&1 || echo "    Erro ao verificar SMART para $disk. Verifique permissões (sudo) ou o tipo de disco (pode não suportar SMART)." >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
    done
else
    echo "Comando 'smartctl' não encontrado. Instale o pacote 'smartmontools' (ex: 'sudo apt install smartmontools' ou 'sudo yum install smartmontools') para obter estas informações." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise SMART Detalhada
echo "### Análise SMART Detalhada ###" >> "$OUTPUT_FILE"
if command -v smartctl &> /dev/null; then
    for disk in $(ls -1 /dev/sd[a-z] /dev/nvme[0-9]n[0-9] /dev/vd[a-z] 2>/dev/null); do
        if [ -b "$disk" ]; then
            echo "  Informações detalhadas SMART para $disk:" >> "$OUTPUT_FILE"
            sudo smartctl -A "$disk" | grep -E "Reallocated_Sector_Ct|Spin_Retry_Count|End-to-End_Error|Reported_Uncorrect|Command_Timeout|Current_Pending_Sector|Offline_Uncorrectable" >> "$OUTPUT_FILE" 2>&1 || echo "    Erro ao obter dados SMART detalhados para $disk." >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
    done
fi
echo "" >> "$OUTPUT_FILE"

# Status de RAID Software (mdadm)
echo "### Status de RAID Software (mdadm - /proc/mdstat) ###" >> "$OUTPUT_FILE"
if [ -f /proc/mdstat ]; then
    cat /proc/mdstat >> "$OUTPUT_FILE"
else
    echo "  /proc/mdstat não encontrado. Nenhum RAID software (mdadm) detectado ou módulo não carregado." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de RAID Avançada
echo "### Análise de RAID Avançada ###" >> "$OUTPUT_FILE"
if command -v mdadm &> /dev/null; then
    echo "Detalhes dos arrays RAID:" >> "$OUTPUT_FILE"
    for md_device in /dev/md*; do
        if [ -b "$md_device" ]; then
            echo "  Detalhes para $md_device:" >> "$OUTPUT_FILE"
            sudo mdadm --detail "$md_device" >> "$OUTPUT_FILE" 2>&1 || echo "    Erro ao obter detalhes do RAID para $md_device." >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
    done
else
    echo "  Comando 'mdadm' não encontrado." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# Verificação de Partições de RAID Linux
echo "### Partições de RAID Linux (fdisk -l) ###" >> "$OUTPUT_FILE"
echo "  Procurando por partições marcadas como 'Linux raid autodetect':" >> "$OUTPUT_FILE"
fdisk -l 2>/dev/null | grep "\*" | grep 'fd  Linux raid autodetect' >> "$OUTPUT_FILE" || echo "  Nenhuma partição de RAID Linux autodetect encontrada." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Detecção de Controladora RAID Hardware (lspci)
echo "### Detecção de Controladora RAID Hardware (lspci) ###" >> "$OUTPUT_FILE"
echo "  Procurando por dispositivos PCI relacionados a RAID:" >> "$OUTPUT_FILE"
lspci | grep -i RAID >> "$OUTPUT_FILE" || echo "  Nenhuma controladora RAID de hardware detectada via lspci." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Informações de Controladoras RAID Específicas (HPACUCLI, MegaCli)
echo "### Informações de Controladoras RAID Específicas (HPACUCLI, MegaCli) ###" >> "$OUTPUT_FILE"
echo "NOTA: Estas ferramentas são proprietárias e só funcionarão se instaladas e configuradas." >> "$OUTPUT_FILE"

# HPACUCLI
if command -v hpacucli &> /dev/null; then
    echo "#### HPACUCLI (Controladoras HP Smart Array) ####" >> "$OUTPUT_FILE"
    echo "  Configuração de Logical Drives e Physical Drives:" >> "$OUTPUT_FILE"
    sudo hpacucli ctrl all show config | egrep 'logicaldrive|physicaldrive' >> "$OUTPUT_FILE" 2>&1 || echo "    Erro ao executar 'hpacucli'. Verifique permissões (sudo) ou status da controladora." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
else
    echo "  Comando 'hpacucli' não encontrado. Se este for um servidor HP com Smart Array, instale o pacote 'hpacucli'." >> "$OUTPUT_FILE"
fi

# MegaCli (LSI/Broadcom MegaRAID)
MEGACLI_PATH="/opt/MegaRAID/MegaCli/MegaCli64"
if [ -x "$MEGACLI_PATH" ]; then # Verifica se o executável existe e tem permissão
    echo "#### MegaCli (Controladoras LSI/Broadcom MegaRAID) ####" >> "$OUTPUT_FILE"
    echo "  Status de Physical Drives:" >> "$OUTPUT_FILE"
    sudo "$MEGACLI_PATH" -PDList -aALL | egrep 'Slot Number|Firmware state|Media Error Count|Other Error Count|Predictive Failure Count|Last Predictive Failure Event Seq Number' >> "$OUTPUT_FILE" 2>&1 || echo "    Erro ao executar 'MegaCli64 -PDList'. Verifique permissões (sudo)." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "  Número de Virtual Disks:" >> "$OUTPUT_FILE"
    sudo "$MEGACLI_PATH" -LdPdInfo -aALL | grep "Number of Virtual Disks" >> "$OUTPUT_FILE" 2>&1 || echo "    Erro ao executar 'MegaCli64 -LdPdInfo'." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
else
    echo "  Executável '$MEGACLI_PATH' não encontrado. Se este for um servidor com MegaRAID, instale o pacote 'MegaCli'." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

# Verificação de Presença do GRUB Bootloader
echo "### Verificação de Presença do GRUB Bootloader ###" >> "$OUTPUT_FILE"
echo "  Verifica se a assinatura 'GRUB' está presente no setor de boot dos discos." >> "$OUTPUT_FILE"
for diskxyz in $(ls /sys/block/ | grep -iE '^sd|nvme|vd' 2>/dev/null); do
    if [ -b "/dev/$diskxyz" ]; then
        echo "  Verificando /dev/$diskxyz..." >> "$OUTPUT_FILE"
        if sudo dd if="/dev/$diskxyz" bs=512 count=1 2>/dev/null | grep -a "GRUB" &> /dev/null; then
            echo "    GRUB encontrado em /dev/$diskxyz" >> "$OUTPUT_FILE"
        else
            echo "    GRUB NÃO encontrado em /dev/$diskxyz" >> "$OUTPUT_FILE"
        fi
    fi
done
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Análise de Boot Avançada
echo "### Análise de Boot Avançada ###" >> "$OUTPUT_FILE"
echo "Configuração do GRUB:" >> "$OUTPUT_FILE"
if [ -f /boot/grub/grub.cfg ]; then
    echo "  Entradas do menu GRUB:" >> "$OUTPUT_FILE"
    grep "menuentry" /boot/grub/grub.cfg | head -n 10 >> "$OUTPUT_FILE"
elif [ -f /boot/grub2/grub.cfg ]; then
    echo "  Entradas do menu GRUB2:" >> "$OUTPUT_FILE"
    grep "menuentry" /boot/grub2/grub.cfg | head -n 10 >> "$OUTPUT_FILE"
else
    echo "  Arquivo de configuração do GRUB não encontrado." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

echo "Tempo de inicialização do sistema:" >> "$OUTPUT_FILE"
systemd-analyze >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao obter tempo de inicialização." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Tempo de inicialização crítico por serviço:" >> "$OUTPUT_FILE"
systemd-analyze critical-chain >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao obter cadeia crítica de inicialização." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Seção 5: Análise de Performance e Monitoramento
echo "## SEÇÃO 5: ANÁLISE DE PERFORMANCE E MONITORAMENTO" >> "$OUTPUT_FILE"
echo "Esta seção fornece métricas de performance em tempo real e análises de tendências do sistema." >> "$OUTPUT_FILE"
echo "----------------------------------------------------------------------------------" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "### Análise de Performance em Tempo Real ###" >> "$OUTPUT_FILE"
echo "Snapshot atual do sistema (top):" >> "$OUTPUT_FILE"
top -b -n1 | head -n 20 >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao executar top." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Processos com maior uso de I/O:" >> "$OUTPUT_FILE"
if command -v iotop &> /dev/null; then
    iotop -b -n1 | head -n 15 >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao executar iotop." >> "$OUTPUT_FILE"
else
    echo "  Comando 'iotop' não encontrado. Instale para obter informações de I/O por processo." >> "$OUTPUT_FILE"
fi
echo "" >> "$OUTPUT_FILE"

echo "Limites de recursos do sistema (ulimit):" >> "$OUTPUT_FILE"
ulimit -a >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Informações de paginação e swap:" >> "$OUTPUT_FILE"
cat /proc/vmstat | grep -E "pswpin|pswpout|pgpgin|pgpgout" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# **NOVO**: Seção 6: Análise de Aplicações e Serviços Específicos
echo "## SEÇÃO 6: ANÁLISE DE APLICAÇÕES E SERVIÇOS ESPECÍFICOS" >> "$OUTPUT_FILE"
echo "Esta seção analisa aplicações e serviços específicos instalados no sistema." >> "$OUTPUT_FILE"
echo "----------------------------------------------------------------------------------" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "### Análise de Banco de Dados ###" >> "$OUTPUT_FILE"
# MySQL/MariaDB
if systemctl is-active --quiet mysql || systemctl is-active --quiet mariadb; then
    echo "Status do MySQL/MariaDB:" >> "$OUTPUT_FILE"
    mysql -e "SHOW PROCESSLIST;" >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao conectar no MySQL/MariaDB." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    echo "Variáveis importantes do MySQL:" >> "$OUTPUT_FILE"
    mysql -e "SHOW VARIABLES LIKE 'max_connections'; SHOW VARIABLES LIKE 'innodb_buffer_pool_size';" >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao obter variáveis do MySQL." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

# PostgreSQL
if systemctl is-active --quiet postgresql; then
    echo "Status do PostgreSQL:" >> "$OUTPUT_FILE"
    sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;" >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao conectar no PostgreSQL." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

echo "### Análise de Servidor Web ###" >> "$OUTPUT_FILE"
# Apache
if systemctl is-active --quiet apache2; then
    echo "Status do Apache:" >> "$OUTPUT_FILE"
    apache2ctl status >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao obter status do Apache." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    echo "Módulos carregados no Apache:" >> "$OUTPUT_FILE"
    apache2ctl -M | head -n 20 >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao listar módulos do Apache." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

# Nginx
if systemctl is-active --quiet nginx; then
    echo "Status do Nginx:" >> "$OUTPUT_FILE"
    nginx -t >> "$OUTPUT_FILE" 2>&1 || echo "  Erro ao testar configuração do Nginx." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

echo "--- FIM DO RELATÓRIO DE ANÁLISE ABRANGENTE DO SERVIDOR LINUX ---" >> "$OUTPUT_FILE"

echo "Relatório de análise abrangente gerado com sucesso em: $OUTPUT_FILE"
echo "Verifique o arquivo '$OUTPUT_FILE' para o relatório completo."