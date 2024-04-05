#!/bin/bash

# Definiere Pfad für die Log-Dateien und SSH-Ziele Datei
LOG_DIR="./logs"
SSH_TARGETS_FILE="ssh_targets.txt"
OUTPUT_DIR_BASE="./command_outputs"

# Vordefinierte Befehle
COMMANDS=("sudo apt update" "Benutzerdefinierter Befehl 2" "Benutzerdefinierter Befehl 3")

# Stelle sicher, dass das Verzeichnis für die Log-Dateien existiert
mkdir -p $LOG_DIR
mkdir -p $OUTPUT_DIR_BASE

manage_ssh_targets() {
    echo "SSH-Ziele verwalten:"
    echo "1. Neues SSH-Ziel hinzufügen"
    echo "2. Bestehendes SSH-Ziel bearbeiten"
    read -p "Option wählen (1 oder 2): " manage_option

    case $manage_option in
        1)
            echo "Alias für das neue SSH-Ziel eingeben:"
            read alias
            echo "Benutzername für die SSH-Verbindung eingeben:"
            read user
            echo "IP-Adresse oder DNS-Name für $alias eingeben:"
            read address
            echo "$alias $user $address" >> $SSH_TARGETS_FILE
            echo "SSH-Ziel $alias wurde hinzugefügt."
            ;;
        2)
            echo "Verfügbare SSH-Ziele:"
            IFS=$'\n' read -d '' -r -a lines < $SSH_TARGETS_FILE
            for i in "${!lines[@]}"; do
                echo "$((i+1)). ${lines[i]}"
            done
            echo "Nummer des zu bearbeitenden Ziels eingeben:"
            read num
            target="${lines[$((num-1))]}"
            echo "Aktuelle Daten: $target"
            echo "Neuen Alias für das SSH-Ziel eingeben (aktuell: ${target%% *}):"
            read new_alias
            echo "Neuen Benutzer für die SSH-Verbindung eingeben (aktuell: ${target%% * }):"
            read new_user
            echo "Neue IP-Adresse oder DNS-Name für $new_alias eingeben (aktuell: ${target##* }):"
            read new_address
            # Ersetze die Zeile im Array
            lines[$((num-1))]="$new_alias $new_user $new_address"
            # Schreibe das Array zurück in die Datei
            > $SSH_TARGETS_FILE
            for line in "${lines[@]}"; do
                echo "$line" >> $SSH_TARGETS_FILE
            done
            echo "SSH-Ziel wurde aktualisiert."
            ;;
        *)
            echo "Ungültige Option."
            ;;
    esac
}

connect_to_server() {
    if [ ! -s $SSH_TARGETS_FILE ]; then
        echo "Keine SSH-Ziele gefunden. Bitte zuerst ein Ziel hinzufügen."
        return
    fi

    echo "Verfügbare SSH-Ziele:"
    IFS=$'\n' read -d '' -r -a lines < $SSH_TARGETS_FILE
    for i in "${!lines[@]}"; do
        echo "$((i+1)). ${lines[i]%% *}"
    done
    echo "Nummer des Ziels eingeben, zu dem verbunden werden soll:"
    read num
    target="${lines[$((num-1))]}"
    alias="${target%% *}"
    user="${target#* }"
    user="${user%% *}"  # Extrahiere den Benutzernamen
    address="${target##* }"

    output_dir="$OUTPUT_DIR_BASE/$alias"
    mkdir -p "$output_dir"

    echo "Verbindung zu $alias ($address) wird hergestellt..."
    while true; do
        echo "Wählen Sie einen Befehl zur Ausführung:"
        for i in "${!COMMANDS[@]}"; do
            echo "$((i+1)). ${COMMANDS[i]}"
        done
        echo "Geben Sie die Nummer des Befehls ein (oder 'exit' zum Zurückkehren):"
        read cmd_num
        if [[ "$cmd_num" == "exit" ]]; then
            break
        fi
        selected_cmd="${COMMANDS[$((cmd_num-1))]}"
        if [ -z "$selected_cmd" ]; then
            echo "Ungültige Auswahl. Bitte versuchen Sie es erneut."
            continue
        fi
        output_file="$output_dir/command_output_$(date +%Y-%m-%d_%H-%M-%S).txt"
        ssh -t ${user}@${address} "$selected_cmd" | tee "$output_file" 2>&1
        exit_code=${PIPESTATUS[0]}
        log_file="$LOG_DIR/${alias}_log.csv"
        if [ ! -f $log_file ]; then
            echo "timestamp,alias,user,address,local_user,command,output_file,exit_code" > $log_file
        fi
        echo "$(date),$alias,$user,$address,$(whoami),\"$selected_cmd\",\"$output_file\",$exit_code" >> $log_file
    done
}

while true; do
    echo "Hauptmenü:"
    echo "1. Mit Server verbinden"
    echo "2. SSH-Ziele verwalten (hinzufügen/bearbeiten)"
    echo "3. Beenden"
    read -p "Option wählen: " option
    case $option in
        1) connect_to_server ;;
        2) manage_ssh_targets ;;
        3) break ;;
        *) echo "Ungültige Option." ;;
    esac
done