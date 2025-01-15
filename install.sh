#!/bin/bash

OS="linux"

__check_os() {
    uname_os=$(uname -s)
    if [ "${uname_os}" == "Darwin" ]; then
        OS="mac"
    elif [ "${uname_os}" == "Linux" ]; then
        OS=$( cat /etc/issue )

        if [[ "$OS" == "Ubuntu"* ]]
        then
            OS="ubuntu"
        elif [[ "$OS" == "Debian"* ]]
        then
            OS="debian"
        elif [[ "$OS" == "Arch"* ]]
        then
            OS="arch"
        else
            echo "Automatic identification of distribution failed, please enter a distribution. (ubuntu, debian, arch, mac)"
            read OS
        fi
    else
        echo "Other OS: ${uname_os}"
        exit 1
    fi
}

__install_depends() {
    case ${OS} in
        ubuntu)
            sudo apt update
            sudo apt install -y zsh vim curl git tmux xclip
            chsh -s $(which zsh)
            ;;
        debian)
            sudo apt update
            sudo apt install -y zsh vim curl git tmux xclip
            chsh -s $(which zsh)
            ;;
        arch)
            sudo pacman -Syyu --noconfirm zsh vim curl git tmux xclip
            chsh -s $(which zsh)
            ;;
        mac)
            brew update
            brew install zsh vim curl git tmux reattach-to-user-namespace
            chsh -s $(which zsh)
            ;;
        *)
            echo "Unsupported distribution."
            exit 1
            ;;
    esac
}

__configure_vim() {
    ln -sf "$(pwd)/.vimrc" "$HOME/.vimrc"
    rm -rf ~/.vim
    git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
    vim +PluginInstall +qall
}

__configure_zsh() {
    ln -sf "$(pwd)/.zshrc" "$HOME/.zshrc"
    rm -rf ~/.oh-my-zsh
    git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
    touch "$HOME/.zsh_machine"
}

__configure_git() {
    ln -sf "$(pwd)/.gitconfig" "$HOME/.gitconfig"
    touch "$HOME/.gitconfig_machine"
}

__configure_tmux() {
    rm -rf ~/.oh-my-tmux
    git clone https://github.com/gpakosz/.tmux.git ~/.oh-my-tmux
    ln -sf "$HOME/.oh-my-tmux/.tmux.conf" "$HOME/.tmux.conf"
    ln -sf "$HOME/.dotfiles/.tmux.conf.local" "$HOME/.tmux.conf.local"
}

__check_os
__install_depends
__configure_vim
__configure_zsh
__configure_git
__configure_tmux

echo 'Done.'
zsh
