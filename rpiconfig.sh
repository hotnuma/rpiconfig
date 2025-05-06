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

# sudoers ---------------------------------------------------------------------

#~ dest=/etc/sudoers.d/10_custom
#~ if [[ ! -f "$dest" ]]; then
    #~ echo "*** sudoers" | tee -a "$outfile"
    #~ sudo tee "$dest" > /dev/null << EOF
#~ Defaults:$currentuser !logfile, !syslog
#~ $currentuser ALL=(ALL) NOPASSWD: ALL
#~ EOF
#~ fi

# autologin -------------------------------------------------------------------

#~ dest=/etc/lightdm/lightdm.conf
#~ if [[ ! -f ${dest}.bak ]]; then
    #~ echo "*** autologin" | tee -a "$outfile"
    #~ sudo cp "$dest" ${dest}.bak 2>&1 | tee -a "$outfile"
    #~ sudo tee "$dest" > /dev/null << EOF
#~ [Seat:*]
#~ autologin-guest=false
#~ autologin-user=$currentuser
#~ autologin-user-timeout=0
#~ autologin-session=lightdm-xsession
#~ EOF
#~ fi

# environment -----------------------------------------------------------------

#~ dest=/etc/environment
#~ if [[ ! -f ${dest}.bak ]]; then
    #~ echo "*** environment" | tee -a "$outfile"
    #~ sudo cp "$dest" ${dest}.bak 2>&1 | tee -a "$outfile"
    #~ sudo tee "$dest" > /dev/null << "EOF"
#~ PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games"
#~ GTK_OVERLAY_SCROLLING=0
#~ NO_AT_BRIDGE=1
#~ EOF
#~ fi

# disable rtkit-daemon spam messages ------------------------------------------

#~ dest=/etc/systemd/system/rtkit-daemon.service.d/
#~ if [[ $(pidof rtkit-daemon) ]] && [[ ! -d ${dest} ]]; then
    #~ echo "*** disable rtkit logs" | tee -a "$outfile"
    #~ sudo mkdir $dest
    #~ dest=/etc/systemd/system/rtkit-daemon.service.d/log.conf
    #~ sudo tee "$dest" > /dev/null << "EOF"
#~ [Service]
#~ LogLevelMax=4
#~ EOF
    #~ sudo systemctl daemon-reload 2>&1 | tee -a "$outfile"
    #~ sudo systemctl restart rtkit-daemon.service 2>&1 | tee -a "$outfile"
#~ fi

# create directories ----------------------------------------------------------

#~ create_dir "$HOME/.config/autostart/"
#~ create_dir "$HOME/.config/labwc/"
#~ create_dir "$HOME/.local/share/applications/"
#~ create_dir "$HOME/.local/share/icons/"
#~ create_dir "$HOME/.local/share/themes/"
#~ create_dir "$HOME/.local/share/xfce4/terminal/colorschemes/"

# install base ================================================================

dest=/usr/bin/xfce4-terminal
if [[ ! -f "$dest" ]]; then
    sys_upgrade
    echo "*** install base" | tee -a "$outfile"
    APPLIST="thunar xfce4-terminal"
    sudo apt -y install $APPLIST 2>&1 | tee -a "$outfile"
    test "$?" -eq 0 || error_exit "installation failed"
fi

# install without recommends --------------------------------------------------

#~ dest=/usr/sbin/smartctl
#~ if [[ ! -f "$dest" ]]; then
    #~ echo "*** install without recommends" | tee -a "$outfile"
    #~ APPLIST="smartmontools"
    #~ sudo apt -y install --no-install-recommends \
        #~ $APPLIST 2>&1 | tee -a "$outfile"
    #~ test "$?" -eq 0 || error_exit "installation failed"
#~ fi

# install QtCreator -----------------------------------------------------------

#~ dest=/usr/bin/qtcreator
#~ if [[ $opt_qtcreator == 1 ]] && [[ ! -f "$dest" ]]; then
    #~ echo "*** install QtCreator" | tee -a "$outfile"
    #~ APPLIST="qtcreator qt6-base-dev"
    #~ sudo apt -y install $APPLIST 2>&1 | tee -a "$outfile"
    #~ test "$?" -eq 0 || error_exit "installation failed"
#~ fi

# install dev packages --------------------------------------------------------

#~ dest=/usr/bin/apt-file
#~ if [[ ! -f "$dest" ]]; then
    #~ echo "*** install dev packages" | tee -a "$outfile"
    #~ APPLIST="apt-file build-essential clang-format gettext git gtk-3-examples"
    #~ APPLIST+=" libglib2.0-doc libgtk-3-dev libgtk-3-doc libxml2-dev meson"
    #~ sudo apt -y install $APPLIST 2>&1 | tee -a "$outfile"
    #~ test "$?" -eq 0 || error_exit "installation failed"
#~ fi

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

#~ which fluidsynth && sudo apt -y purge fluidsynth 2>&1 | tee -a "$outfile"
#~ which mpris-proxy && sudo apt -y purge bluez 2>&1 | tee -a "$outfile"
#~ which thd && sudo apt -y purge triggerhappy 2>&1 | tee -a "$outfile"
#~ which vlc && sudo apt -y purge vlc 2>&1 | tee -a "$outfile"

#~ if [[ "$(pidof exim4)" ]]; then
    #~ echo "*** uninstall exim4" | tee -a "$outfile"
    #~ sudo apt -y purge exim4-base 2>&1 | tee -a "$outfile"
#~ fi

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

#~ if [[ "$(pidof blkmapd)" ]]; then
    #~ echo "*** disable nfs-blkmap" | tee -a "$outfile"
    #~ sudo systemctl stop nfs-blkmap 2>&1 | tee -a "$outfile"
    #~ sudo systemctl disable nfs-blkmap 2>&1 | tee -a "$outfile"
#~ fi

#~ if [[ "$(pidof bluetoothd)" ]]; then
    #~ echo "*** disable bluetooth" | tee -a "$outfile"
    #~ sudo systemctl stop bluetooth 2>&1 | tee -a "$outfile"
    #~ sudo systemctl disable bluetooth 2>&1 | tee -a "$outfile"
#~ fi

#~ if [[ -f "/etc/systemd/system/smartd.service" ]]; then
    #~ echo "*** disable smartd" | tee -a "$outfile"
    #~ sudo systemctl stop smartd 2>&1 | tee -a "$outfile"
    #~ sudo systemctl disable smartd 2>&1 | tee -a "$outfile"
#~ fi

#~ if [[ "$(pidof sshd)" ]]; then
    #~ echo "*** disable sshd" | tee -a "$outfile"
    #~ sudo systemctl stop sshd 2>&1 | tee -a "$outfile"
    #~ sudo systemctl disable sshd 2>&1 | tee -a "$outfile"
#~ fi

# system settings =============================================================

#~ dest=/usr/local/bin/startup.sh
#~ if [[ ! -f "$dest" ]]; then
    #~ echo "*** startup.sh" | tee -a "$outfile"
    #~ sudo cp "$basedir/root/startup.sh" "$dest" 2>&1 | tee -a "$outfile"
    #~ dest="$HOME/.config/autostart/startup.desktop"
    #~ cp "$basedir/home/startup.desktop" "$dest" 2>&1 | tee -a "$outfile"
#~ fi

# user settings ===============================================================

#~ dest="$HOME/config"
#~ if [[ ! -L "$dest" ]]; then
    #~ echo "*** config link" | tee -a "$outfile"
    #~ ln -s "$HOME/.config" "$dest" 2>&1 | tee -a "$outfile"
    #~ echo "*** add user to adm group" | tee -a "$outfile"
    #~ sudo usermod -a -G adm $currentuser 2>&1 | tee -a "$outfile"
#~ fi

# aliases ---------------------------------------------------------------------

#~ dest="$HOME/.bash_aliases"
#~ if [[ ! -f "$dest" ]]; then
    #~ echo "*** aliases" | tee -a "$outfile"
    #~ cp "$basedir/home/bash_aliases" "$dest" 2>&1 | tee -a "$outfile"
#~ fi

# wallpaper -------------------------------------------------------------------

#~ dest="$HOME/.config/wallpaper"
#~ if [[ ! -f "$dest" ]]; then
    #~ echo "*** wallpaper" | tee -a "$outfile"
    #~ cp "$basedir/home/wallpaper" "$dest" 2>&1 | tee -a "$outfile"
#~ fi

# xfce settings ===============================================================

#~ dest=/etc/xdg/xfce4
#~ if [[ "$opt_xfce" -eq 1 ]] \
#~ && [[ -d "$dest" ]] && [[ ! -d "${dest}.bak" ]]; then

    #~ echo "*** copy xdg xfce4" | tee -a "$outfile"
    #~ sudo cp -r "$dest" "${dest}.bak" 2>&1 | tee -a "$outfile"
    #~ test "$?" -eq 0 || error_exit "backup xfce4-session.xml failed"
    #~ dest="/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml"
    #~ sudo cp "$basedir/root/xfce4-session.xml" "$dest" 2>&1 | tee -a "$outfile"
    #~ test "$?" -eq 0 || error_exit "copy xfce4-session.xml failed"

    #~ echo "*** xfconf settings" | tee -a "$outfile"
    #~ xfconf-query --create -c keyboards -p '/Default/Numlock' \
        #~ -t 'bool' -s 'true' 2>&1 | tee -a "$outfile"
    #~ xfconf-query -c xfwm4 -p '/general/workspace_count' \
        #~ -s 1 2>&1 | tee -a "$outfile"
    #~ xfconf-query -c xfce4-appfinder -np '/enable-service' \
        #~ -t 'bool' -s 'false' 2>&1 | tee -a "$outfile"
    #~ xfconf-query -c xfce4-session -np '/shutdown/ShowHibernate' \
        #~ -t 'bool' -s 'false' 2>&1 | tee -a "$outfile"
    #~ xfconf-query -c xfce4-session -np '/shutdown/ShowHybridSleep' \
        #~ -t 'bool' -s 'false' 2>&1 | tee -a "$outfile"
    #~ xfconf-query -c xfce4-session -np '/shutdown/ShowSuspend' \
        #~ -t 'bool' -s 'false' 2>&1 | tee -a "$outfile"
#~ fi

# keyboard-shortcuts ----------------------------------------------------------

#~ destdir="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
#~ dest="$destdir/xfce4-keyboard-shortcuts.xml"
#~ if [[ "$opt_xfce" -eq 1 ]] \
#~ && [[ -f "$dest" ]] && [[ ! -f "${dest}.bak" ]]; then
    #~ echo "*** xfce4-keyboard-shortcuts.xml" | tee -a "$outfile"
    #~ mv "$dest" "${dest}.bak" 2>&1 | tee -a "$outfile"
    #~ test "$?" -eq 0 || error_exit "backup xfce4-keyboard-shortcuts.xml failed"
    #~ cp "$basedir/home/xfce4-keyboard-shortcuts.xml" \
       #~ "$dest" 2>&1 | tee -a "$outfile"
    #~ test "$?" -eq 0 || error_exit "copy xfce4-keyboard-shortcuts.xml failed"
#~ fi    

# panel -----------------------------------------------------------------------

#~ destdir="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
#~ dest="$destdir/xfce4-panel.xml"
#~ if [[ "$opt_xfce" -eq 1 ]] \
#~ && [[ -f "$dest" ]] && [[ ! -f "${dest}.bak" ]]; then
    #~ echo "*** xfce4-panel.xml" | tee -a "$outfile"
    #~ mv "$dest" "${dest}.bak" 2>&1 | tee -a "$outfile"
    #~ test "$?" -eq 0 || error_exit "backup xfce4-panel.xml failed"
    #~ cp "$basedir/home/xfce4-panel.xml" \
       #~ "$dest" 2>&1 | tee -a "$outfile"
    #~ test "$?" -eq 0 || error_exit "copy xfce4-panel.xml failed"
#~ fi

# thunar uca ------------------------------------------------------------------

#~ dest="$HOME/.config/Thunar/uca.xml"
#~ if [[ "$opt_xfce" -eq 1 ]] && [[ -f "$dest" ]] && [[ ! -f ${dest}.bak ]]; then
    #~ echo "*** thunar terminal" | tee -a "$outfile"
    #~ mv "$dest" "${dest}.bak" 2>&1 | tee -a "$outfile"
    #~ cp "$basedir/home/uca.xml" "$dest" 2>&1 | tee -a "$outfile"
#~ fi

# xfce4-terminal --------------------------------------------------------------

#~ dest="$HOME/.local/share/xfce4/terminal/colorschemes/custom.theme"
#~ if [[ ! -f "$dest" ]]; then
    #~ echo "*** terminal colors" | tee -a "$outfile"
    #~ cp "$basedir/home/custom.theme" "$dest" 2>&1 | tee -a "$outfile"
#~ fi

# build programs ==============================================================

#~ dest="$builddir"
#~ if [[ ! -d "$dest" ]]; then
    #~ echo "*** create build dir" | tee -a "$outfile"
    #~ mkdir "$builddir"
#~ fi

#~ pushd "$builddir" 1>/dev/null

#~ dest=/usr/include/gumbo.h
#~ if [[ ! -f "$dest" ]]; then
    #~ echo "*** install libraries" | tee -a "$outfile"
    #~ APPLIST="libgd-dev libgudev-1.0-dev libgumbo-dev libmediainfo-dev"
    #~ APPLIST+=" libnotify-dev libwnck-3-dev libxfce4ui-2-dev libxfconf-0-dev"
    #~ APPLIST+=" libxmu-dev libxss-dev xfce4-dev-tools"
    #~ sudo apt -y install $APPLIST 2>&1 | tee -a "$outfile"
    #~ test "$?" -eq 0 || error_exit "installation failed"
#~ fi

#~ dest="/usr/local/include/tinyc/cstring.h"
#~ build_src "libtinyc" "$dest"
#~ test -f "$dest" || error_exit "compilation failed"

#~ dest="/usr/local/include/tinyui/etkaction.h"
#~ build_src "libtinyui" "$dest"
#~ test -f "$dest" || error_exit "compilation failed"

#~ dest="/usr/local/bin/fileman"
#~ build_src "fileman" "$dest"
#~ test -f "$dest" || error_exit "compilation failed"

#~ dest="/usr/local/bin/sysquery"
#~ build_src "sysquery" "$dest"
#~ test -f "$dest" || error_exit "compilation failed"

#~ dest="/usr/local/bin/colortest"
#~ build_src "systools" "$dest"
#~ test -f "$dest" || error_exit "compilation failed"

#~ dest="/usr/local/bin/xfce4-taskmanager"
#~ build_src "taskman" "$dest"
#~ test -f "$dest" || error_exit "compilation failed"

#~ dest="/usr/local/bin/applist"
#~ build_src "applist" "$dest"
#~ test -f "$dest" || error_exit "compilation failed"

#~ dest="/usr/local/bin/firebook"
#~ build_src "firebook" "$dest"
#~ test -f "$dest" || error_exit "compilation failed"

#~ dest="/usr/local/bin/mpvcmd"
#~ build_src "mpvcmd" "$dest"
#~ test -f "$dest" || error_exit "compilation failed"

#~ dest="/usr/local/bin/volman"
#~ build_src "volman" "$dest"
#~ test -f "$dest" || error_exit "compilation failed"

#~ dest="/usr/local/bin/imgview"
#~ if [[ ! -f "$dest" ]]; then
    #~ sudo apt -y install libexiv2-dev libgdk-pixbuf-2.0-dev
    #~ build_src "imgview" "$dest"
    #~ test -f "$dest" || error_exit "compilation failed"
#~ fi

#~ dest=/usr/local/bin/hoedown
#~ if [[ ! -f "$dest" ]]; then
    #~ echo "*** build hoedown" | tee -a "$outfile"
    #~ git clone https://github.com/hoedown/hoedown.git 2>&1 | tee -a "$outfile"
    #~ pushd hoedown 1>/dev/null
    #~ make && sudo make install 2>&1 | tee -a "$outfile"
    #~ sudo strip /usr/local/bin/hoedown 2>&1 | tee -a "$outfile"
#~ fi

#~ # powerctl --------------------------------------------------------------------

#~ dest="/usr/local/bin/powerctl"
#~ build_src "powerctl" "$dest"
#~ test -f "$dest" || error_exit "compilation failed"

#~ dest="$HOME/.config/autostart/powerctl.desktop"
#~ if [[ -f "/usr/local/bin/powerctl" ]] \
#~ && [[ ! -f "$dest" ]]; then
    #~ echo "*** powerctl" | tee -a "$outfile"
    #~ cp "$basedir/home/powerctl.desktop" "$dest" 2>&1 | tee -a "$outfile"
#~ fi

#~ # Disable autostart programs --------------------------------------------------

#~ hide_launcher "$HOME/.config/autostart/nm-applet.desktop"
#~ hide_launcher "$HOME/.config/autostart/print-applet.desktop"
#~ hide_launcher "$HOME/.config/autostart/pwrkey.desktop"
#~ hide_launcher "$HOME/.config/autostart/xdg-user-dirs.desktop"
#~ hide_launcher "$HOME/.config/autostart/xfce4-clipman-plugin-autostart.desktop"
#~ hide_launcher "$HOME/.config/autostart/xiccd.desktop"
#~ hide_launcher "$HOME/.config/autostart/xscreensaver.desktop"

#~ # Hide Applications -----------------------------------------------------------

#~ hide_application "fileman"
#~ hide_application "gcr-prompter"
#~ hide_application "gcr-viewer"
#~ hide_application "RealTimeSync"
#~ hide_application "system-config-printer"
#~ hide_application "thunar-bulk-rename"
#~ hide_application "thunar-settings"
#~ hide_application "thunar-volman-settings"
#~ hide_application "xfce-backdrop-settings"
#~ hide_application "xfce4-appfinder"
#~ hide_application "xfce4-file-manager"
#~ hide_application "xfce4-mail-reader"
#~ hide_application "xfce4-run"
#~ hide_application "xfce4-web-browser"

#~ hide_launcher "$HOME/.local/share/applications/thunar.desktop"

#~ # cleanup =====================================================================

#~ if [[ "$opt_cleanup" -eq 1 ]]; then
    #~ dest="/usr/bin/plymouth"
    #~ if [[ -f "$dest" ]]; then
        #~ echo "*** uninstall plymouth" | tee -a "$outfile"
        #~ sudo apt -y purge plymouth 2>&1 | tee -a "$outfile"
    #~ fi
    #~ popd 1>/dev/null
    #~ echo "done" | tee -a "$outfile"
    #~ exit 0
#~ fi

#~ # labwc =======================================================================

#~ if [[ "$opt_labwc" -eq 0 ]]; then
    #~ popd 1>/dev/null
    #~ echo "done" | tee -a "$outfile"
    #~ exit 0
#~ fi

#~ # install wayland softwares ---------------------------------------------------

#~ dest=/usr/bin/swaybg
#~ if [[ ! -f "$dest" ]]; then
    #~ echo "*** install wayland softwares" | tee -a "$outfile"
    #~ APPLIST="labwc swaybg swayidle wlopm"
    #~ sudo apt -y install $APPLIST 2>&1 | tee -a "$outfile"
    #~ test "$?" -eq 0 || error_exit "installation failed"
#~ fi

#~ # config files ----------------------------------------------------------------

#~ dest="$HOME/.config/labwc"
#~ test -d "$dest" || mkdir -p "$dest"
#~ if [[ ! -d "${dest}.bak" ]]; then
    #~ echo "*** install labwc files" | tee -a "$outfile"
    #~ cp -r "$dest" "${dest}.bak"
    #~ test "$?" -eq 0 || error_exit "install labwc files failed"
    #~ cp "$basedir/labwc/autostart" "$dest/"
    #~ test "$?" -eq 0 || error_exit "install labwc files failed"
    #~ cp "$basedir/labwc/environment" "$dest/"
    #~ test "$?" -eq 0 || error_exit "install labwc files failed"
    #~ cp "$basedir/labwc/rc.xml" "$dest/"
    #~ test "$?" -eq 0 || error_exit "install labwc files failed"
#~ fi

#~ # Notwaita White Cursors ------------------------------------------------------

#~ dest="$HOME/.local/share/icons"
#~ if [[ ! -d "$dest/NotwaitaWhite" ]]; then
    #~ echo "*** install NotwaitaWhite cursors" | tee -a "$outfile"
    #~ src="$basedir/labwc/cursors-notwaita-white.zip"
    #~ unzip -d "$dest" "$src" 2>&1 | tee -a "$outfile"
    #~ test "$?" -eq 0 || error_exit "installation failed"
#~ fi

#~ # AdwaitaRevisitedLight -------------------------------------------------------

#~ dest="$HOME/.local/share/themes"
#~ if [[ ! -d "$dest/AdwaitaRevisitedLight" ]]; then
    #~ echo "*** install AdwaitaRevisitedLight theme" | tee -a "$outfile"
    #~ src="$basedir/labwc/theme-adwaita-light.zip"
    #~ unzip -d "$dest" "$src" 2>&1 | tee -a "$outfile"
    #~ test "$?" -eq 0 || error_exit "installation failed"
#~ fi

#~ # wl-clip-persist -------------------------------------------------------------

#~ dest="/usr/local/bin"
#~ if [[ $cpu == "aarch64" ]] && [[ ! -f "$dest/wl-clip-persist" ]]; then
    #~ echo "*** install wl-clip-persist" | tee -a "$outfile"
    #~ src="$basedir/labwc/wl-clip-persist-aarch64.zip"
    #~ sudo unzip -d "$dest" "$src" 2>&1 | tee -a "$outfile"
    #~ test "$?" -eq 0 || error_exit "installation failed"
#~ fi

#~ # labwc-tweaks-gtk ------------------------------------------------------------

#~ dest=/usr/local/bin/labwc-tweaks-gtk
#~ if [[ ! -f "$dest" ]]; then
    #~ echo "*** build labwc-tweaks-gtk" | tee -a "$outfile"
    #~ git clone https://github.com/labwc/labwc-tweaks-gtk.git \
    #~ && pushd labwc-tweaks-gtk 1>/dev/null
    #~ meson setup build -Dbuildtype=release | tee -a "$outfile"
    #~ meson compile -C build | tee -a "$outfile"
    #~ sudo meson install -C build | tee -a "$outfile"
    #~ test "$?" -eq 0 || error_exit "installation failed"
    #~ popd 1>/dev/null
#~ fi

#~ # rofi ------------------------------------------------------------

#~ dest=/usr/local/bin/rofi
#~ if [[ ! -f "$dest" ]]; then
    #~ echo "*** build rofi" | tee -a "$outfile"
    #~ sudo apt -y install bison flex
    #~ git clone https://github.com/lbonn/rofi.git \
    #~ && pushd rofi 1>/dev/null
    #~ meson setup build -Dbuildtype=release -Dcheck=disabled -Dxcb=disabled \
    #~ | tee -a "$outfile"
    #~ ninja -C build | tee -a "$outfile"
    #~ sudo ninja -C build install | tee -a "$outfile"
    #~ popd 1>/dev/null
#~ fi

#~ # terminate ===================================================================

#~ popd 1>/dev/null
#~ echo "done" | tee -a "$outfile"


