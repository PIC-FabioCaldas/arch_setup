#
# ~/.bashrc
#

eval "$(starship init bash)"

## Only run the rest of this file if the shell is interactive (not a script)
[[ $- != *i* ]] && return

# Alias: 'ls' will show colored output for files and directories
alias ls='ls --color=auto'
# Alias: 'grep' will highlight matches in color
alias grep='grep --color=auto'

# _____YAZI SETUP_____
export EDITOR="code" 
# shell wrapper that provides the ability to change the current working directory when exiting Yazi.
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}


# __________THESIS__________
# _____PIPX install path_____
export PATH="$HOME/.local/bin:$PATH"

# _____LATEX things for thesis_____
export PATH=$PATH:/usr/local/texlive/2025/bin/x86_64-linux
export CHTEXRC=/usr/local/texlive/2025/texmf-dist/chktex/chktexrc
export PATH=/usr/local/texlive/2025/bin/x86_64-linux:$PATH
export TEXMFROOT=/usr/local/texlive/2025
export TEXMFSYSVAR=/usr/local/texlive/2025/texmf-var
export TEXMFSYSCONFIG=/usr/local/texlive/2025/texmf-config
export TEXMFLOCAL=/usr/local/texlive/texmf-local
export TEXMFDIST=/usr/local/texlive/2025/texmf-dist
