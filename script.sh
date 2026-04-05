#!/bin/bash 

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
CSV_FILE="$SCRIPT_DIR/utilizatori.csv"
LOGGED_FILE="$SCRIPT_DIR/.logged_users"
HOME_DIR_BASE="$SCRIPT_DIR/home"

generate_id() {
  date +%s%N | sha256sum | cut -c1-10
}

hash_password() {
  echo -n "$1" | sha256sum | cut -d' ' -f1
}

user_exists() {
  grep -q ",$1," "$CSV_FILE"
}

validate_email() {
  [[ "$1" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

inregistrare() {
  [ ! -e "$CSV_FILE" ] && echo "ID,Username,Email,PasswordHash,LastLogin" > "$CSV_FILE"

  read -p "Introduceți numele de utilizator: " USERNAME
  if user_exists "$USERNAME"; then
    echo "Utilizatorul '$USERNAME' există deja."
    return
  fi

  read -p "Introduceți adresa de email: " EMAIL
  if ! validate_email "$EMAIL"; then
    echo "Email invalid!"
    return
  fi

  read -s -p "Introduceți parola: " PASSWORD
  echo
  read -s -p "Confirmați parola: " CONFIRM_PASSWORD
  echo

  if [ "$PASSWORD" != "$CONFIRM_PASSWORD" ]; then
    echo "Parolele nu se potrivesc!"
    return
  fi

  HASHED_PASS=$(hash_password "$PASSWORD")
  USER_ID=$(generate_id)
  echo "$USER_ID,$USERNAME,$EMAIL,$HASHED_PASS,NECUNOSCUT" >> "$CSV_FILE"
  echo "Utilizatorul '$USERNAME' a fost înregistrat cu succes."

  mkdir -p "$HOME_DIR_BASE/$USERNAME"
  echo "Director home creat: $HOME_DIR_BASE/$USERNAME"

  EMAIL_SUBJECT="Confirmare Înregistrare"
  EMAIL_BODY=$(cat <<EOF
Salut $USERNAME,

Contul tău a fost creat cu succes.
ID-ul tău este: $USER_ID

Mulțumim!
EOF
)

  if echo "$EMAIL_BODY" | mail -s "$EMAIL_SUBJECT" "$EMAIL"; then
    echo "Email de confirmare trimis către $EMAIL"
  else
    echo "Atenție: emailul nu a putut fi trimis către $EMAIL"
  fi
}

login() {
  echo -n "Introduceți numele de utilizator: "
  read username
  if [ ! -f "$CSV_FILE" ]; then
    echo "Fișierul utilizatori.csv nu există!"
    return
  fi

  user_line=$(grep ",$username," "$CSV_FILE")
  if [ -z "$user_line" ]; then
    echo "Utilizatorul nu există!"
    return
  fi

  stored_hash=$(echo "$user_line" | cut -d',' -f4)
  echo -n "Introduceți parola: "
  read -s password
  echo

  entered_hash=$(echo -n "$password" | sha256sum | cut -d' ' -f1)
  if [ "$entered_hash" == "$stored_hash" ]; then
    echo "Autentificare reușită!"
    home_dir="$HOME_DIR_BASE/$username"
    [ ! -d "$home_dir" ] && mkdir -p "$home_dir"
    cd "$home_dir" || exit

    echo "$username" >> "$LOGGED_FILE"

    # Update last login
    sed -i "s/\(^[^,]*,$username,[^,]*,[^,]*,\).*/\1$(date '+%Y-%m-%d %H:%M:%S')/" "$CSV_FILE"

    echo "Navigat în directorul $home_dir"
  else
    echo "Parolă incorectă!"
  fi
}

logout() {
  echo -n "Introduceți numele de utilizator pentru logout: "
  read username
  username=$(echo "$username" | tr -d '\r\n[:space:]')

  if [ ! -f "$LOGGED_FILE" ]; then
    echo "Niciun utilizator nu este autentificat."
    return
  fi

  found=0
  > "$LOGGED_FILE.tmp"  # Creează fișier temporar gol

  while read -r line; do
    clean_line=$(echo "$line" | tr -d '\r\n[:space:]')
    if [ "$clean_line" != "$username" ]; then
      echo "$clean_line" >> "$LOGGED_FILE.tmp"
    else
      found=1
    fi
  done < "$LOGGED_FILE"

  mv "$LOGGED_FILE.tmp" "$LOGGED_FILE"

  if [ "$found" -eq 1 ]; then
    echo "$username a fost delogat!"
  else
    echo "$username nu este autentificat."
  fi
}

generare_raport() {
  if [ ! -f "$CSV_FILE" ]; then
    echo "Fișierul utilizatori.csv nu există. Întâi înregistrează un utilizator!"
    return
  fi

  echo -n "Introduceți numele de utilizator pentru generarea raportului: "
  read username
  if ! grep -q ",$username," "$CSV_FILE"; then
    echo "Utilizatorul nu există în baza de date!"
    return
  fi

  user_home="$HOME_DIR_BASE/$username"
  raport_file="$user_home/raport.txt"

  if [ ! -d "$user_home" ]; then
    echo "Directorul home pentru utilizator nu există: $user_home"
    return
  fi

  {
    num_files=$(find "$user_home" -type f | wc -l)
    num_dirs=$(find "$user_home" -type d | wc -l)
    total_size=$(du -sh "$user_home" | cut -f1)
    {
      echo "Raport pentru utilizatorul: $username"
      echo "-------------------------------"
      echo "Număr de fișiere: $num_files"
      echo "Număr de directoare: $num_dirs"
      echo "Dimensiune totală pe disc: $total_size"
      echo "Generat la: $(date '+%Y-%m-%d %H:%M:%S')"
    } > "$raport_file"
  } > /dev/null 2>&1 &

  echo "Raportul este generat în background și va fi salvat în $raport_file"
}

afiseaza_autentificati() {
  if [ -f "$LOGGED_FILE" ]; then
    echo "Utilizatori autentificați:"
    sort "$LOGGED_FILE"
  else
    echo "Niciun utilizator nu este autentificat."
  fi
}

while true; do
  echo
  echo "Meniu principal:"
  echo "1. Înregistrare utilizator"
  echo "2. Login"
  echo "3. Logout"
  echo "4. Lista utilizatori autentificați"
  echo "5. Generare raport utilizator"
  echo "6. Iesire"
  echo -n "Alegeți opțiunea: "
  read opt
  case "$opt" in
    1) inregistrare ;;
    2) login ;;
    3) logout ;;
    4) afiseaza_autentificati ;;
    5) generare_raport ;;
    6) echo "La revedere!"; break ;;
    *) echo "Opțiune invalidă!" ;;
  esac
done
