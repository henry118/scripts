# User dependent .bashrc file

# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

# History related
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize

# Terminal color
if [ -n "$DISPLAY" -a "$TERM" == "xterm" ]; then
    export TERM=xterm-256color
fi
case "$TERM" in
    xterm-color|xterm-256color) color_prompt=yes;;
esac
if [ "$color_prompt" = yes ]; then
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='\u@\h:\w\$ '
fi

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# Aliases
if [ -f "${HOME}/.bash_aliases" ]; then
   source "${HOME}/.bash_aliases"
fi
case $(uname) in
Linux)
    alias ls='ls --color=auto'
    alias dir='ls --color=auto --format=vertical'
    alias vdir='ls --color=auto --format=long'
    alias pbcopy='xclip -selection clipboard'
    alias pbpaste='xclip -selection clipboard -o'
    ;;
FreeBSD|Darwin)
    alias ls='ls -G'
    ;;
CYGWIN_NT-*)
    alias ls='ls --color=auto'
    alias wp='cygpath -w'
    alias ophere='explorer `wp .`'
    alias open='cygstart'
    alias pbcopy='putclip'
    alias pbpaste='getclip'
    echo -ne '\e]4;12;#9090FF\a'
    ;;
esac
alias less='less -r'
alias grep='grep --color'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias cgrep='grep --color=always'
alias ngrep='grep -n'
alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'
alias diff='diff -u'
alias em='emacsclient -nw'
alias cless='LESSOPEN="|lessfilter %s" less'
alias nless='less -N'
alias ccat='pygmentize -f 256'
alias wget-jpg='wget -r -l 1 -A jpg,jpeg -nd -H -q'

# Umask
# /etc/profile sets 022, removing write perms to group + others.
# Set a more restrictive umask: i.e. no exec perms for others:
# umask 027
# Paranoid: neither group nor others have any perms:
# umask 077

# Functions
if [ -f "${HOME}/.bash_functions" ]; then
    source "${HOME}/.bash_functions"
fi

# Colored Manpages (To customize the colors, see Wikipedia:ANSI escape code for reference)
# man() {
#     env LESS_TERMCAP_mb=$'\E[01;31m' \
#     LESS_TERMCAP_md=$'\E[01;38;5;74m' \
#     LESS_TERMCAP_me=$'\E[0m' \
#     LESS_TERMCAP_se=$'\E[0m' \
#     LESS_TERMCAP_so=$'\E[38;5;246m' \
#     LESS_TERMCAP_ue=$'\E[0m' \
#     LESS_TERMCAP_us=$'\E[04;38;5;146m' \
#     man "$@"
# }

# Source work env related settings
if [ -f "${HOME}/devel/cp_scripts/bashrc" ]; then
   source "${HOME}/devel/cp_scripts/bashrc"
fi

# Setup ibus
export GTK_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export QT_IM_MODULE=ibus

# Maven
export MAVEN_OPTS="-XX:MaxPermSize=256m -Xmx1024M"
