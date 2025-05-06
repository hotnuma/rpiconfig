#!/usr/bin/bash

basedir="$(dirname -- "$(readlink -f -- "$0";)")"
builddir="$HOME/DevFiles"
currentuser="$USER"
outfile="$HOME/install.log"
dist_id=""
cpu=$(arch)

error_exit()
{
    msg="$1"
    test "$msg" != "" || msg="an error occurred"
    printf "*** $msg\nabort...\n" | tee -a "$outfile"
    exit 1
}

create_dir()
{
    test "$1" != "" || error_exit "create_dir failed"
    test ! -d "$1" || return
    echo "*** create_dir : $1"
    mkdir -p "$1"
}

sys_upgrade()
{
    echo "*** sys upgrade" | tee -a "$outfile"
    sudo apt update 2>&1 | tee -a "$outfile"
    test "$?" -eq 0 || error_exit "update failed"
    sudo apt full-upgrade 2>&1 | tee -a "$outfile"
    test "$?" -eq 0 || error_exit "upgrade failed"
}

install_file()
{
    test "$#" == 2 || error_exit "install_file must take 2 parameters"
    src=$1
    dest=$2
    local destdir=$(dirname $dest)
    if [[ ! -d "$destdir" ]]; then
        warning "$destdir doesn't exist"
        return
    fi
    test ! -f "${dest}.bak" || return
    echo "install_file $src $dest"
    test -f "$src" || error_exit "source file doesn't exist"
    if [[ "$dest" == "/home"* ]]; then
        test -f "$dest" || touch "$dest"
        mv "$dest" "${dest}.bak" 2>&1 | tee -a "$outfile"
        test "$?" -eq 0 || error_exit "mv $dest ${dest}.bak failed"
        cp "$src" "$dest" 2>&1 | tee -a "$outfile"
        test "$?" -eq 0 || error_exit "cp $src $dest failed"
    else
        test -f "$dest" || sudo touch "$dest"
        sudo mv "$dest" "${dest}.bak" 2>&1 | tee -a "$outfile"
        test "$?" -eq 0 || error_exit "sudo mv $dest ${dest}.bak failed"
        sudo cp "$src" "$dest" 2>&1 | tee -a "$outfile"
        test "$?" -eq 0 || error_exit "sudo cp $src $dest failed"
    fi
}

hide_launcher()
{
    test "$1" != "" || error_exit "hide_launcher failed"
    test ! -f "$1" || return
    echo "*** hide : $1"
    printf "[Desktop Entry]\nHidden=True\n" > "$1"
}

filemod()
{
    if [[ ! -f "$1" ]]; then
        echo "file ${1} doesn't exist" | tee -a "$outfile"
        return
    fi
    filename=$(basename "$1")
    echo "*** hide : ${filename}" | tee -a "$outfile"
    dest="$HOME/.local/share/applications/$filename"
    cp "$1" "$HOME/.local/share/applications/"
    sed -i '/^MimeType=/d' "$dest" | tee -a "$outfile"
    echo "NoDisplay=true" >> "$dest"
}

hide_application()
{
    dest="$HOME/.local/share/applications/${1}.desktop"
    test ! -f "$dest" || return
    dest="/usr/local/share/applications/${1}.desktop"
    if [[ -f "$dest" ]]; then
        filemod $dest
        return
    fi
    dest="/usr/share/applications/${1}.desktop"
    if [[ -f "$dest" ]]; then
        filemod $dest
        return
    fi
}

build_src()
{
    local pack="$1"
    local dest="$2"
    if [[ ! -f "$dest" ]]; then
        echo "*** build ${pack}" | tee -a "$outfile"
        git clone https://github.com/hotnuma/${pack}.git 2>&1 | tee -a "$outfile"
        pushd ${pack} 1>/dev/null
        ./install.sh 2>&1 | tee -a "$outfile"
        popd 1>/dev/null
    fi
}

# tests =======================================================================

if [[ "$EUID" = 0 ]]; then
    error_exit "*** must not be run as root"
else
    # make sure to ask for password on next sudo
    sudo -k
    if ! sudo true; then
        error_exit "*** sudo failed"
    fi
fi

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    dist_id=$VERSION_CODENAME
fi

# start =======================================================================

echo "===============================================================================" | tee -a $outfile
echo " Debian install..." | tee -a $outfile
echo "===============================================================================" | tee -a $outfile

# install base ================================================================

dest=/usr/bin/xfce4-terminal
if [[ ! -f "$dest" ]]; then
    sys_upgrade
    echo "*** install base" | tee -a "$outfile"
    APPLIST="thunar xfce4-terminal"
    sudo apt -y install $APPLIST 2>&1 | tee -a "$outfile"
    test "$?" -eq 0 || error_exit "installation failed"
fi

# uninstall ===================================================================

dest=/usr/bin/plymouth
if [[ -f "$dest" ]]; then
    echo "*** uninstall softwares" | tee -a "$outfile"
    APPLIST="plymouth"
    sudo apt -y purge $APPLIST 2>&1 | tee -a "$outfile"
    test "$?" -eq 0 || error_exit "uninstall failed"
    sudo apt -y autoremove 2>&1 | tee -a "$outfile"
    test "$?" -eq 0 || error_exit "autoremove failed"
fi

# services --------------------------------------------------------------------

#~ if [ "$(pidof cupsd)" ]; then
    #~ echo "*** disable services" | tee -a "$outfile"
    #~ APPLIST="anacron apparmor avahi-daemon cron cups cups-browsed"
    #~ APPLIST+=" ModemManager"
    #~ sudo systemctl stop $APPLIST 2>&1 | tee -a "$outfile"
    #~ sudo systemctl disable $APPLIST 2>&1 | tee -a "$outfile"
    #~ APPLIST="anacron.timer apt-daily.timer apt-daily-upgrade.timer"
    #~ sudo systemctl stop $APPLIST 2>&1 | tee -a "$outfile"
    #~ sudo systemctl disable $APPLIST 2>&1 | tee -a "$outfile"
#~ fi



