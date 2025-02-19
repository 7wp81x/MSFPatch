#!/bin/bash

error="\e[1;31m[!]\e[0m"
info="\e[1;34m[*]\e[0m"
success="\e[1;32m[+]\e[0m"
input="\e[1;36m[?]\e[0m"


for pkg in ruby lolcat figlet pv; do
    if ! command -v "$pkg" &>/dev/null; then
        [[ "$pkg" == "lolcat" ]] && gem install lolcat || pkg install -y "$pkg"
    fi
done
printf '\033\143'
cat .logo | lolcat -a -d 3
printf "\033[1;96m:: Apktool build patch for metasploit ::\033[0m\n"
printf "\033[1;96m         .:. \033[1;92mAuthor - 7wp81x\033[1;96m.:.\033[0m\n\n"

if [[ ! -d "/data/data/com.termux/files/usr" ]]; then
    printf "$error This script is only for Termux.\n"
    exit 1
fi

ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" && "$ARCH" != "x86_64" ]]; then
    printf "$error Unsupported architecture: $ARCH. This script supports aarch64 and x86_64.\n"
    exit 1
fi


patchMSF() {
    printf "$info Installing required packages...\n"
    pkg install openjdk-17 android-tools apksigner qemu-user-x86-64 -y
    printf "$info Installing Apktool...\n"
    cp apktool $PREFIX/bin/apktool
    cp apktool.jar $PREFIX/bin/apktool.jar
    chmod +x $PREFIX/bin/apktool*
    termux-fix-shebang $PREFIX/bin/apktool
    printf "$success Apktool installed!\n"

    printf "$success Install complete!\n"
    printf "$info Extracting aapt2_64 from apktool.jar...\n"
    mkdir -p $PREFIX/share/ApktoolMod
    jar -xvf $PREFIX/bin/apktool.jar prebuilt/linux/aapt2_64
    mv prebuilt/linux/aapt2_64 $PREFIX/share/ApktoolMod/aapt2_64.elf

    printf "$info Creating wrapper script for aapt2_64...\n"
    cat <<EOF > $PREFIX/share/ApktoolMod/aapt2_64
#!/data/data/com.termux/files/usr/bin/bash
if ! command -v qemu-x86_64 &> /dev/null; then
    echo "qemu-x86_64 is not installed. Please install it to use this wrapper."
    exit 1
fi

BINARY="\$(dirname "\$0")/\$(basename "\$0").elf"

if [ ! -f "\$BINARY" ]; then
    echo "\$BINARY not found in the script's directory."
    exit 1
fi

exec qemu-x86_64 "\$BINARY" "\$@"
EOF

    chmod a+x $PREFIX/share/ApktoolMod/aapt2_64 $PREFIX/share/ApktoolMod/aapt2_64.elf
    printf "$success aapt2_64 patched and ready!\n"
    rm -rf prebuilt
    patchApkRb
}

patchApkRb() {
    printf "$info Searching for apk.rb..."
    APK_RB_PATH=$(find $PREFIX -type f -name "apk.rb" 2>/dev/null | grep "metasploit-framework/lib/msf/core/payload/")
    if [[ -f "$APK_RB_PATH" ]]; then
        sleep 2
        cp $APK_RB_PATH $APK_RB_PATH.bk
        printf "$info Patching apk.rb...\n"
        cp apk_mod $APK_RB_PATH
        printf "$success apk.rb patched successfully!\n"
    else
        printf "$error apk.rb not found. Patch failed.\n"
    fi
}

installMSF() {
    printf "$info Installing Metasploit...\n"
    pkg update -y && pkg upgrade -y
    pkg install -y wget
    wget https://raw.githubusercontent.com/gushmazuko/metasploit_in_termux/master/metasploit.sh -O metasploit.sh
    chmod +x metasploit.sh
    bash metasploit.sh
    printf "$success Metasploit installation complete!\n"
}

selectOPTS() {
    while true; do
        printf "$input Do you want to install metasploit (Y/n)?: "
        read -r opt
        case "$opt" in
            N|n)
                printf "$info Exiting...\n"
                exit 0
                ;;
            Y|y)
                installMSF
                patchMSF
                break
                ;;

            *)
                printf "$error Invalid option...\n"
                ;;
        esac
    done
}

checkMSF() {
    if [[ ! $(command -v msfconsole) ]]; then
        printf "$error Metasploit is not installed...?\n"
        selectOPTS
    else
        printf "$success Metasploit found!\n"
        patchMSF
    fi
}

# Run check
checkMSF
