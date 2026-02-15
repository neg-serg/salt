
_exists rg && {
    alias -g RG="rg"
    alias -g zrg="rg -z"
}

_exists sudo && {
    local sudo_list=(chmod chown modprobe umount)
    local logind_sudo_list=(reboot halt poweroff)
    for c in ${sudo_list[@]}; {_exists "$c" && alias "$c=sudo $c"}
}
_exists journalctl && journalctl() {command journalctl "${@:--b}";}
_exists mpc && {
    cdm(){
        dirname="$XDG_MUSIC_DIR/$(dirname "$(mpc -f '%file%'|head -1)")"
        cd "$dirname"
    }
}
_exists curl && {
    geoip(){ curl ipinfo.io/$1; }
    sprunge(){ curl -F "sprunge=<-" http://sprunge.us <"$1" ;}
}
_exists docker && {
    carbonyl(){docker run --rm -ti fathyb/carbonyl https://youtube.com}
    ipmi_one(){ docker run -p 127.0.0.1:5900:5900 -p 127.0.0.1:8080:8080 gari123/ipmi-kvm-docker; echo xdg-open http://127.0.0.1:8080|wl-copy }
    ipmi_two(){ docker run -p 8080:8080 solarkennedy/ipmi-kvm-docker; echo xdg-open localhost:8080|wl-copy }
}

_exists broot && autoload -Uz br

autoload zc

# vim: ft=zsh:nowrap
