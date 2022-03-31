#!/bin/bash


# Keep-alive: update existing `sudo` time stamp until finished
# while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

dir=~/dotfiles-minimal            # dotfiles directory
olddir=~/dotfiles_old             # old dotfiles backup directory
platform=$(uname)
pacman_args="--noconfirm --needed"

# list of files/folders to symlink in homedir
# oh-my-zsh
# gruvbox
# fzf.zsh
files="
config
vimrc
tmux
tmux.conf
"
overrides="
zshrc_local
vimrc_local
tmux_local.conf
nvim_local.vimrc
profile.local
gitconfig
pypirc
"
NPM="
livedown
yo
generator-meanjs
tldr
"
# install pacaur on Arch Linux
AUR="
pacaur
"
APT="
vim
tree
"
ARCH="
"

# Returns 1 if program is installed and 0 otherwise
function program_installed {
    local return_=1

    type $1 >/dev/null 2>&1 || { local return_=0; }

    echo "$return_"
}

function link_dotfiles {
    # create dotfiles_old in homedir
    echo -n "Creating $olddir for backup of any existing dotfiles in ~ ..."
    mkdir -p $olddir

    # change to the dotfiles directory
    cd $dir

    # move any existing dotfiles in homedir to dotfiles_old directory, then create symlinks from the
    # homedir to any files in the ~/dotfiles directory specified in $files
    for file in $files; do
        if [[ -f $file || -d $file ]]; then
            echo ""
            if [[ -f ~/.$file || -d ~/.$file ]]; then
                echo "Moving : .$file (~/.$file -> $olddir/.$file)"
                rm -r $olddir/.$file
                mv ~/.$file $olddir/
            fi
            echo "Linking: $file ($dir/$file -> ~/.$file)"
            ln -s $dir/$file ~/.$file
        fi
    done
    for file in $overrides; do
        if [[ -f dotfile_overrides/$file || -d dotfile_overrides/$file ]]; then
            echo ""
            if [[ -f ~/.$file || -d ~/.$file ]]; then
                echo "Moving : .$file (~/.$file -> $olddir/.$file)"
                rm -r $olddir/.$file
                mv ~/.$file $olddir/
            fi
            echo "Linking: $file ($dir/dotfile_overrides/$file -> ~/.$file)"
            ln -s $dir/dotfile_overrides/$file ~/.$file
        fi
    done
}

function install_AUR() {
    # install AUR programs if on Arch
    if [ $(program_installed pacman) == 1 ]; then
        echo -n "Do you want to upgrade/install from AUR? (y/n) "
        read response
        if [[ $response == 'y' ]] || [[ $response == 'Y' ]]; then
            echo "Creating ~/builds to hold AUR programs."
            mkdir -p ~/builds
            echo "Installing git if it's not installed."
            sudo pacman -Sq $pacman_args git
            echo "Installing base-devel if it's not installed."
            sudo pacman -Sq $pacman_args base-devel
            echo "Installing pacaur."
            for program in $AUR; do
                if [[ ! -d ~/builds/$program ]]; then
                    echo "Git cloning $program to ~/builds/$program ."
                    git clone https://aur.archlinux.org/$program.git ~/builds/$program
                    cd ~/builds/$program
                    # Problem here with still being root
                    makepkg -sri $pacman_args
                    cd $dir
                fi
            done
            echo "Installing AUR programs through pacaur."
            pacaur -Syua $pacman_args
            echo -n "Would you like to install all AUR programs? (y/n) "
            read response
            if [[ $response == 'y' ]] || [[ $response == 'Y' ]]; then
                echo "Installing AUR programs."
                for program in $PACAUR; do
                    # if [ $(program_installed $program) == 0 ]; then
                        pacaur -Sqa $pacman_args $program
                    # fi
                done
            fi
        fi
    fi
}

function install_programs() {
    if [ $(program_installed pacman) == 1 ]; then
        sudo pacman -Syuq
        for program in $ARCH; do
            sudo pacman -Sq $pacman_args $program
        done
    elif [ $(program_installed apt-get) == 1 ]; then
        sudo apt-get update
        for program in $APT; do
            sudo apt-get install $program
        done
    else
        echo "Cannot install tools, no compatible package manager."
    fi

    # cd into $dir
    cd $dir
}

function install_npm() {
    for program in $NPM; do
        sudo npm install -g $program
    done
}

function fix_package_query() {
    if [ $(program_installed pacman) == 1 ]; then
        echo "Removing old installs."
        if [ $(program_installed package-query) == 1 ]; then
            sudo pacman -Rdd package-query
        fi
        if [ $(program_installed pacaur) == 1 ]; then
            # TODO: Will this work?
            sudo pacman -Rdd pacaur
        fi
        echo "Upgrading system."
        sudo pacman -Syuq
        echo "Creating ~/builds to hold AUR programs."
        mkdir -p ~/builds
        echo "Installing git if it's not installed."
        sudo pacman -Sq $pacman_args git
        echo "Installing base-devel if it's not installed."
        sudo pacman -Sq $pacman_args base-devel
        echo "Installing package_query and pacaur."
        cd ~/builds
        echo "Removing old builds if they exist."
        rm -rf package-query
        rm -rf pacaur
        git clone https://aur.archlinux.org/package-query.git ~/builds/package-query
        cd ~/builds/package-query
        makepkg -sri $pacman_args
        git clone https://aur.archlinux.org/pacaur.git ~/builds/pacaur
        cd ~/builds/pacaur
        makepkg -sri $pacman_args
        cd $dir
    fi
}

function push_dotfiles() {
    cd $dir
    echo "Pushing dotfiles"
    git add -A
    git commit
    git push origin master
}

function update_dotfiles() {
    cd $dir
    git pull
}

function main() {
    echo "[complete] Complete install and configuration"
    echo "[push] Push to github"
    echo "[pull] Pull from github"
    echo "[dotfiles] Install dotfiles only"
    if [ $(program_installed pacman) == 1]; then
        echo "[programs] Install programs (pacman, pacaur, npm) only"
    elif [ $(program_installed apt-get) == 1]; then
        echo "[programs] Install programs (apt-get, npm) only"
    fi
    if [ $(program_installed pacman) == 1]; then
        echo "[programs-no-aur] Install official repository programs (pacman, npm) only"
        echo "[aur-only] Install AUR programs only"
        echo "[package-query] Fix outdated package-query"
    fi
    echo "[npm] Install npm packages only"
    echo "[0] Quit"
    echo ""
    echo "What would you like to do?"
    read response
    if [[ $response == "complete" ]]; then
        link_dotfiles
        install_programs
        install_AUR
        install_github
        install_pip
        install_npm
        install_gems
        install_rust_src
        install_zsh
        install_nerd_fonts
        install_powerline_fonts
        configure_system
        configure_freetype2
    elif [[ $response == "push" ]]; then
        push_dotfiles
    elif [[ $response == "pull" ]]; then
        update_dotfiles
    elif [[ $response == "dotfiles" ]]; then
        link_dotfiles
        echo ""
        main
    elif [[ $response == "programs" ]]; then
        install_programs
        install_AUR
        install_github
        install_pip
        install_npm
        install_gems
        echo ""
        main
    elif [[ $response == "programs-no-aur" ]]; then
        install_programs
        echo ""
        main
    elif [[ $response == "aur-only" ]]; then
        install_AUR
        main
    elif [[ $response == "package-query" ]]; then
        fix_package_query
        echo ""
        main
    elif [[ $response == "npm" ]]; then
        install_npm
        echo ""
        main
    fi
}

main
