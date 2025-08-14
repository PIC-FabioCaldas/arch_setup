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
export EDITOR="nvim" 
# shell wrapper that provides the ability to change the current working directory when exiting Yazi.
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}