#!/bin/bash
# This script should be run via curl:
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/okryuk/dotfiles/main/install.sh)" "" --all
# or via wget:
#   sh -c "$(wget -qO- https://raw.githubusercontent.com/okryuk/dotfiles/main/install.sh)"
# or via fetch:
#   sh -c "$(fetch -o - https://raw.githubusercontent.com/okryuk/dotfiles/main/install.sh)"
#
# You can also download it first and then run locally with different variables.
#   wget https://raw.githubusercontent.com/okryuk/dotfiles/main/install.sh
#   chmod +x install.sh
#   ./install.sh --all
#
#
# Some functions of this code related to oh-my-zsh setup were copied from 
# an amazing work of Mark Cornella and can be found at https://github.com/ohmyzsh/ohmyzsh

# $USER is defined by login(1) which is not always executed (e.g. containers)
# POSIX: https://pubs.opengroup.org/onlinepubs/009695299/utilities/id.html
USER=${USER:-$(id -u -n)}
# $HOME is defined at the time of login, but it could be unset. If it is unset,
# a tilde by itself (~) will not be expanded to the current user's home directory.
# POSIX: https://pubs.opengroup.org/onlinepubs/009696899/basedefs/xbd_chap08.html#tag_08_03
HOME="${HOME:-$(getent passwd $USER 2>/dev/null | cut -d: -f6)}"
# macOS does not have getent, but this works even if $HOME is unset
HOME="${HOME:-$(eval echo ~$USER)}"

# Track if $ZSH was provided
custom_zsh=${ZSH:+yes}

# Use $zdot to keep track of where the directory is for zsh dotfiles
# To check if $ZDOTDIR was provided, explicitly check for $ZDOTDIR
zdot="${ZDOTDIR:-$HOME}"

# Default value for $ZSH
# a) if $ZDOTDIR is supplied and not $HOME: $ZDOTDIR/ohmyzsh
# b) otherwise, $HOME/.oh-my-zsh
[ "$ZDOTDIR" = "$HOME" ] || ZSH="${ZSH:-${ZDOTDIR:+$ZDOTDIR/ohmyzsh}}"
ZSH="${ZSH:-$HOME/.oh-my-zsh}"

# Default settings
REPO=${REPO:-ohmyzsh/ohmyzsh}
REMOTE=${REMOTE:-https://github.com/${REPO}.git}
BRANCH=${BRANCH:-master}

# Other options
CHSH=${CHSH:-yes}
RUNZSH=${RUNZSH:-yes}
KEEP_ZSHRC=${KEEP_ZSHRC:-no}

# Check if command exists.
# Explanation: 
# "$@": all arguments of a script or function call.
# >: means redirect stdout (same as 1>).
# >/dev/null: means redirect stdout to /dev/null, meaning just trash the output.
# 2>&1 Redirect errout (2>) to stdout (&1).
command_exists() {
  command -v "$@" >/dev/null 2>&1
}


user_can_sudo() {
  # Check if sudo is installed
  command_exists sudo || return 1
  # Termux can't run sudo, so we can detect it and exit the function early.
  case "$PREFIX" in
  *com.termux*) return 1 ;;
  esac
  # The following command has 3 parts:
  #
  # 1. Run `sudo` with `-v`. Does the following:
  #    • with privilege: asks for a password immediately.
  #    • without privilege: exits with error code 1 and prints the message:
  #      Sorry, user <username> may not run sudo on <hostname>
  #
  # 2. Pass `-n` to `sudo` to tell it to not ask for a password. If the
  #    password is not required, the command will finish with exit code 0.
  #    If one is required, sudo will exit with error code 1 and print the
  #    message:
  #    sudo: a password is required
  #
  # 3. Check for the words "may not run sudo" in the output to really tell
  #    whether the user has privileges or not. For that we have to make sure
  #    to run `sudo` in the default locale (with `LANG=`) so that the message
  #    stays consistent regardless of the user's locale.
  #
  ! LANG= sudo -n -v 2>&1 | grep -q "may not run sudo"
}

setup_ohmyzsh() {
  # Create ZDOTDIR folder structure if it doesn't exist
  if [ -n "$ZDOTDIR" ]; then
    mkdir -p "$ZDOTDIR"
  fi

  # Prevent the cloned repository from having insecure permissions. Failing to do
  # so causes compinit() calls to fail with "command not found: compdef" errors
  # for users with insecure umasks (e.g., "002", allowing group writability). Note
  # that this will be ignored under Cygwin by default, as Windows ACLs take
  # precedence over umasks except for filesystems mounted with option "noacl".
  umask g-w,o-w

  echo "$Cloning Oh My Zsh..."

  command_exists git || {
    fmt_error "git is not installed"
    exit 1
  }

  ostype=$(uname)
  if [ -z "${ostype%CYGWIN*}" ] && git --version | grep -Eq 'msysgit|windows'; then
    fmt_error "Windows/MSYS Git is not supported on Cygwin"
    fmt_error "Make sure the Cygwin git package is installed and is first on the \$PATH"
    exit 1
  fi

  # Manual clone with git config options to support git < v1.7.2
  git init --quiet "$ZSH" && cd "$ZSH" \
  && git config core.eol lf \
  && git config core.autocrlf false \
  && git config fsck.zeroPaddedFilemode ignore \
  && git config fetch.fsck.zeroPaddedFilemode ignore \
  && git config receive.fsck.zeroPaddedFilemode ignore \
  && git config oh-my-zsh.remote origin \
  && git config oh-my-zsh.branch "$BRANCH" \
  && git remote add origin "$REMOTE" \
  && git fetch --depth=1 origin \
  && git checkout -b "$BRANCH" "origin/$BRANCH" || {
    [ ! -d "$ZSH" ] || {
      cd -
      rm -rf "$ZSH" 2>/dev/null
    }
    fmt_error "git clone of oh-my-zsh repo failed"
    exit 1
  }
  # Exit installation directory
  cd -

  git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

  echo
}

setup_zshrc() {
  # Keep most recent old .zshrc at .zshrc.pre-oh-my-zsh, and older ones
  # with datestamp of installation that moved them aside, so we never actually
  # destroy a user's original zshrc
  echo "Looking for an existing zsh config..."

  # Must use this exact name so uninstall.sh can find it
  OLD_ZSHRC="$zdot/.zshrc.pre-oh-my-zsh"
  if [ -f "$zdot/.zshrc" ] || [ -h "$zdot/.zshrc" ]; then
    # Skip this if the user doesn't want to replace an existing .zshrc
    if [ "$KEEP_ZSHRC" = yes ]; then
      echo "Found ${zdot}/.zshrc. Keeping..."
      return
    fi
    if [ -e "$OLD_ZSHRC" ]; then
      OLD_OLD_ZSHRC="${OLD_ZSHRC}-$(date +%Y-%m-%d_%H-%M-%S)"
      if [ -e "$OLD_OLD_ZSHRC" ]; then
        fmt_error "$OLD_OLD_ZSHRC exists. Can't back up ${OLD_ZSHRC}"
        fmt_error "re-run the installer again in a couple of seconds"
        exit 1
      fi
      mv "$OLD_ZSHRC" "${OLD_OLD_ZSHRC}"

      echo "Found old .zshrc.pre-oh-my-zsh." \
        "Backing up to ${OLD_OLD_ZSHRC}"
    fi
    echo "Found ${zdot}/.zshrc.Backing up to ${OLD_ZSHRC}"
    mv "$zdot/.zshrc" "$OLD_ZSHRC"
  fi

  echo "Using the Oh My Zsh setup file and adding it to $zdot/.zshrc."
  
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH/custom/themes/powerlevel10k
  wget -O $zdot/.p10k.zsh --backups=1 https://raw.githubusercontent.com/okryuk/dotfiles/main/.p10k.zsh  
  wget -O $zdot/.zshrc --backups=1 https://raw.githubusercontent.com/okryuk/dotfiles/main/.zshrc
  wget -O $ZSH/custom/aliases.zsh --backups=1 https://raw.githubusercontent.com/okryuk/dotfiles/main/.oh-my-zsh/custom/aliases.zsh

  echo
}

# ZSH logic to finish the setup with changing the default shell to ZSH.
setup_zsh_shell() {
  # If this user's login shell is already "zsh", do not attempt to switch.
  if [ "$(basename -- "$SHELL")" = "zsh" ]; then
    return
  fi

  # Check if we're running on Termux
  case "$PREFIX" in
    *com.termux*) termux=true; zsh=zsh ;;
    *) termux=false ;;
  esac

  if [ "$termux" != true ]; then
    # Test for the right location of the "shells" file
    if [ -f /etc/shells ]; then
      shells_file=/etc/shells
    elif [ -f /usr/share/defaults/etc/shells ]; then # Solus OS
      shells_file=/usr/share/defaults/etc/shells
    else
      fmt_error "could not find /etc/shells file. Change your default shell manually."
      return
    fi

    # Get the path to the right zsh binary
    # 1. Use the most preceding one based on $PATH, then check that it's in the shells file
    # 2. If that fails, get a zsh path from the shells file, then check it actually exists
    if ! zsh=$(command -v zsh) || ! grep -qx "$zsh" "$shells_file"; then
      if ! zsh=$(grep '^/.*/zsh$' "$shells_file" | tail -n 1) || [ ! -f "$zsh" ]; then
        fmt_error "no zsh binary found or not present in '$shells_file'"
        fmt_error "change your default shell manually."
        return
      fi
    fi
  fi

  # We're going to change the default shell, so back up the current one
  if [ -n "$SHELL" ]; then
    echo "$SHELL" > "$zdot/.shell.pre-oh-my-zsh"
  else
    grep "^$USER:" /etc/passwd | awk -F: '{print $7}' > "$zdot/.shell.pre-oh-my-zsh"
  fi

  echo "Changing your shell to $zsh..."

  # Check if user has sudo privileges to run `chsh` with or without `sudo`
  #
  # This allows the call to succeed without password on systems where the
  # user does not have a password but does have sudo privileges, like in
  # Google Cloud Shell.
  #
  # On systems that don't have a user with passwordless sudo, the user will
  # be prompted for the password either way, so this shouldn't cause any issues.
  #
  if user_can_sudo; then
    sudo -k chsh -s "$zsh" "$USER"  # -k forces the password prompt
  else
    chsh -s "$zsh" "$USER"          # run chsh normally
  fi

  # Check if the shell change was successful
  if [ $? -ne 0 ]; then
    fmt_error "chsh command unsuccessful. Change your default shell manually."
  else
    export SHELL="$zsh"
    echo "Shell successfully changed to '$zsh'."
  fi

  echo
}

setup_nvim() {
  sudo apt-get install fuse libfuse2 git python3-pip ack-grep -y
  wget --quiet https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage --output-document nvim
  chmod +x nvim
  sudo chown root:root nvim
  sudo mv nvim /usr/bin
  mkdir -p $zdot/.config/nvim
  wget -O $zdot/.config/nvim/init.lua --backups=1 https://raw.githubusercontent.com/okryuk/dotfiles/main/.config/Nvim/init.lua
}

setup_go() {
  wget https://go.dev/dl/go1.20.6.linux-amd64.tar.gz
  tar -xvf go1.20.6.linux-amd64.tar.gz
  mv go go-1.20
  sudo mv go-1.20 /usr/local
  
  if [ -f "$zdot/.zshrc" ] || [ -h "$zdot/.zshrc" ]; then
    cat >> $zdot/.zshrc << EOL

export GOROOT=/usr/local/go-1.20
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
EOL
  else
    cat >> $zdot/.bashrc << EOL

export GOROOT=/usr/local/go-1.20
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
EOL
  fi
}

setup_node() {
  curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash - &&\
  sudo apt-get install -y nodejs
  source ~/.zshrc
}

setup_jest() {
 npm install --save-dev jest
}

linux_setup() {
    # Update apt repo
    # sudo apt update
    sudo apt-get update
    for pkg in $pkgs; do
      echo "Checking $pkg"
      # 2>&1 will capture the error if any
      status="$(dpkg-query -W --showformat='${db:Status-Status}' "$pkg" 2>&1)"
      if [ ! $? = 0 ] || [ ! "$status" = installed ]; then
        echo "Installing $pkg"
        case "$pkg" in
          nvim) 
            setup_nvim ;;
          zsh) 
           command_exists zsh || sudo apt-get install zsh -y ;
           setup_ohmyzsh ;
           setup_zshrc ;
           setup_zsh_shell ;;
          tmux) 
           command_exists tmux || sudo apt-get install tmux -y ;
           wget -O $zdot/.tmux.conf --backups=1 https://raw.githubusercontent.com/okryuk/dotfiles/main/.tmux.conf ;;
	  go) 
           setup_go ;;
	  node)
           setup_node ;;
          *) sudo apt install $pkg ;;
        esac
      fi
    done
}

mac_setup() {
  echo "It's MacOs"
  # Logic to be added later
}

main() {
  # Check if STDIN is a tty
  if [ -t 0 ]; then
    # Man test if the $# (number of parameters) provided is -gt (greater than) 0
    while [ $# -gt 0 ]; do
     # Read and match the second (1) argument
     case $1 in
	--all) pkgs='vim nvim tmux exa zsh'; RUNZSH=no;  ;;
        --go) pkgs='go' ;;
	--nvim) pkgs='vim nvim' ;;
        --node) pkgs='node' ;;
	--vim) pkgs='vim' ;;
        --exa) pkgs='exa' ;;
        --zsh) pkgs='zsh' ;;
        --tmux) pkgs='tmux' ;;
        --zshsetup) pkgs='zshstp' ;;
     esac
     shift
   done
  # If it is not a tty then run as unattended
  else 
    RUNZSH=no
    CHSH=no
  fi

  case $(uname | tr '[:upper:]' '[:lower:]') in
    linux*)
      linux_setup ;;
    darwin*)
      mac_setup  ;;
    msys*)
      echo "It's windows"
      ;;
    *)
      ;;
  esac

  exec zsh -l
}

main "$@"
