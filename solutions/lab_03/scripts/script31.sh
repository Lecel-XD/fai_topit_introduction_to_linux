#!/bin/bash
checks() {
    if (( EUID != 0 )); then
        echo "[ERROR] Permission denied." >&2
        exit 1
    fi
    if [ "$#" -ne 2 ]; then
        echo "[ERROR] Expected 2 arguments, got $#." >&2
        exit 1
    fi
    for arg in "$@"; do
        if ! [[ "$arg" =~ ^[0-9]+$ ]]; then
            echo "[ERROR] $arg is not an integer" >&2
            exit 1
        fi
    done
}


checks "$@"

start=$2
amount=$1

for (( i=start; i<start+amount; i++ )); do
    username="u$i"
    password="DerParol$i"
    if id $username &>/dev/null; then
        echo "User $username already exists. Skipping..."
        continue
    fi

    if useradd -m -s /bin/bash "$username"; then
        echo "$username:$password" | chpasswd
        echo "Success. User $username had been created."
    else
        echo "[ERROR] couldn't create $username." >&2
    fi
done


