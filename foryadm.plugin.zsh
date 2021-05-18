#!/usr/bin/env bash
# MIT (c) Wenxuan Zhang
foryadm::warn() { printf "%b[Warn]%b %s\n" '\e[0;33m' '\e[0m' "$@" >&2; }
foryadm::info() { printf "%b[Info]%b %s\n" '\e[0;32m' '\e[0m' "$@" >&2; }
foryadm::inside_work_tree() { yadm rev-parse --is-inside-work-tree >/dev/null; }

# https://github.com/wfxr/emoji-cli
hash emojify &>/dev/null && foryadm_emojify='|emojify'

foryadm_pager=${FORYADM_PAGER:-$(yadm config core.pager || echo 'cat')}
foryadm_show_pager=${FORYADM_SHOW_PAGER:-$(yadm config pager.show || echo "$foryadm_pager")}
foryadm_diff_pager=${FORYADM_DIFF_PAGER:-$(yadm config pager.diff || echo "$foryadm_pager")}
foryadm_ignore_pager=${FORYADM_IGNORE_PAGER:-$(hash bat &>/dev/null && echo 'bat -l gitignore --color=always' || echo 'cat')}

foryadm_log_format=${FORYADM_LOG_FORMAT:-%C(auto)%h%d %s %C(black)%C(bold)%cr%Creset}

# yadm commit viewer
foryadm::log() {
    foryadm::inside_work_tree || return 1
    local cmd opts graph files
    files=$(sed -nE 's/.* -- (.*)/\1/p' <<< "$*") # extract files parameters for `yadm show` command
    cmd="echo {} |grep -Eo '[a-f0-9]+' |head -1 |xargs -I% yadm show --color=always % -- $files | $foryadm_show_pager"
    opts="
        $FORYADM_FZF_DEFAULT_OPTS
        +s +m --tiebreak=index
        --bind=\"enter:execute($cmd | LESS='-r' less)\"
        --bind=\"ctrl-y:execute-silent(echo {} |grep -Eo '[a-f0-9]+' | head -1 | tr -d '[:space:]' |${FORYADM_COPY_CMD:-pbcopy})\"
        $FORYADM_LOG_FZF_OPTS
    "
    graph=--graph
    [[ $FORYADM_LOG_GRAPH_ENABLE == false ]] && graph=
    eval "yadm log $graph --color=always --format='$foryadm_log_format' $* $foryadm_emojify" |
        FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd"
}

# yadm diff viewer
foryadm::diff() {
    foryadm::inside_work_tree || return 1
    local cmd files opts commit repo
    [[ $# -ne 0 ]] && {
        if yadm rev-parse "$1" -- &>/dev/null ; then
            commit="$1" && files=("${@:2}")
        else
            files=("$@")
        fi
    }
    repo="$(yadm rev-parse --show-toplevel)"
    cmd="echo {} |sed 's/.*]  //' |xargs -I% yadm diff --color=always $commit -- '$repo/%' | $foryadm_diff_pager"
    opts="
        $FORYADM_FZF_DEFAULT_OPTS
        +m -0 --bind=\"enter:execute($cmd |LESS='-r' less)\"
        $FORYADM_DIFF_FZF_OPTS
    "
    eval "yadm diff --name-status $commit -- ${files[*]} | sed -E 's/^(.)[[:space:]]+(.*)$/[\1]  \2/'" |
        FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd"
}

# yadm add selector
foryadm::add() {
    foryadm::inside_work_tree || return 1
    # Add files if passed as arguments
    [[ $# -ne 0 ]] && yadm add "$@" && yadm status -su && return

    local changed unmerged untracked files opts preview extract
    changed=$(yadm config --get-color color.status.changed red)
    unmerged=$(yadm config --get-color color.status.unmerged red)
    untracked=$(yadm config --get-color color.status.untracked red)
    # NOTE: paths listed by 'yadm status -su' mixed with quoted and unquoted style
    # remove indicators | remove original path for rename case | remove surrounding quotes
    extract="
        sed 's/^.*]  //' |
        sed 's/.* -> //' |
        sed -e 's/^\\\"//' -e 's/\\\"\$//'"
    preview="
        file=\$(echo {} | $extract)
        if (yadm status -s -- \$file | grep '^??') &>/dev/null; then  # diff with /dev/null for untracked files
            yadm diff --color=always --no-index -- /dev/null \$file | $foryadm_diff_pager | sed '2 s/added:/untracked:/'
        else
            yadm diff --color=always -- \$file | $foryadm_diff_pager
        fi"
    opts="
        $FORYADM_FZF_DEFAULT_OPTS
        -0 -m --nth 2..,..
        $FORYADM_ADD_FZF_OPTS
    "
    files=$(yadm -c color.status=always -c status.relativePaths=true status -su |
        grep -F -e "$changed" -e "$unmerged" -e "$untracked" |
        sed -E 's/^(..[^[:space:]]*)[[:space:]]+(.*)$/[\1]  \2/' |
        FZF_DEFAULT_OPTS="$opts" fzf --preview="$preview" |
        sh -c "$extract")
    [[ -n "$files" ]] && echo "$files"| tr '\n' '\0' |xargs -0 -I% yadm add % && yadm status -su && return
    echo 'Nothing to add.'
}

# yadm reset HEAD (unstage) selector
foryadm::reset::head() {
    foryadm::inside_work_tree || return 1
    local cmd files opts
    cmd="yadm diff --cached --color=always -- {} | $foryadm_diff_pager "
    opts="
        $FORYADM_FZF_DEFAULT_OPTS
        -m -0
        $FORYADM_RESET_HEAD_FZF_OPTS
    "
    files="$(yadm diff --cached --name-only --relative | FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd")"
    [[ -n "$files" ]] && echo "$files" | tr '\n' '\0' | xargs -0 -I% yadm reset -q HEAD % && yadm status --short && return
    echo 'Nothing to unstage.'
}

# yadm stash viewer
foryadm::stash::show() {
    foryadm::inside_work_tree || return 1
    local cmd opts
    cmd="echo {} |cut -d: -f1 |xargs -I% yadm stash show --color=always --ext-diff % |$foryadm_diff_pager"
    opts="
        $FORYADM_FZF_DEFAULT_OPTS
        +s +m -0 --tiebreak=index --bind=\"enter:execute($cmd | LESS='-r' less)\"
        $FORYADM_STASH_FZF_OPTS
    "
    yadm stash list | FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd"
}

# yadm clean selector
foryadm::clean() {
    foryadm::inside_work_tree || return 1
    local files opts
    opts="
        $FORYADM_FZF_DEFAULT_OPTS
        -m -0
        $FORYADM_CLEAN_FZF_OPTS
    "
    # Note: Postfix '/' in directory path should be removed. Otherwise the directory itself will not be removed.
    files=$(yadm clean -xdffn "$@"| sed 's/^Would remove //' | FZF_DEFAULT_OPTS="$opts" fzf |sed 's#/$##')
    [[ -n "$files" ]] && echo "$files" | tr '\n' '\0' | xargs -0 -I% yadm clean -xdff '%' && yadm status --short && return
    echo 'Nothing to clean.'
}

foryadm::cherry::pick() {
    local base target preview opts
    base=$(yadm branch --show-current)
    [[ -z $1 ]] && echo "Please specify target branch" && return 1
    target="$1"
    preview="echo {1} | xargs -I% yadm show --color=always % | $foryadm_show_pager"
    opts="
        $FORYADM_FZF_DEFAULT_OPTS
        -m -0
    "
    yadm cherry "$base" "$target" --abbrev -v | cut -d ' ' -f2- |
        FZF_DEFAULT_OPTS="$opts" fzf --preview="$preview" | cut -d' ' -f1 |
        xargs -I% yadm cherry-pick %
}

foryadm::rebase() {
    foryadm::inside_work_tree || return 1
    local cmd preview opts graph files commit
    graph=--graph
    [[ $FORYADM_LOG_GRAPH_ENABLE == false ]] && graph=
    cmd="yadm log $graph --color=always --format='$foryadm_log_format' $* $foryadm_emojify"
    files=$(sed -nE 's/.* -- (.*)/\1/p' <<< "$*") # extract files parameters for `yadm show` command
    preview="echo {} |grep -Eo '[a-f0-9]+' |head -1 |xargs -I% yadm show --color=always % -- $files | $foryadm_show_pager"
    opts="
        $FORYADM_FZF_DEFAULT_OPTS
        +s +m --tiebreak=index
        --bind=\"ctrl-y:execute-silent(echo {} |grep -Eo '[a-f0-9]+' | head -1 | tr -d '[:space:]' |${FORYADM_COPY_CMD:-pbcopy})\"
        $FORYADM_REBASE_FZF_OPTS
    "
    commit=$(eval "$cmd" | FZF_DEFAULT_OPTS="$opts" fzf --preview="$preview" |
        grep -Eo '[a-f0-9]+' | head -1)
    [[ -n "$commit" ]] && yadm rebase -i "$commit"
}

foryadm::fixup() {
    foryadm::inside_work_tree || return 1
    yadm diff --cached --quiet && echo 'Nothing to fixup: there are no staged changes.' && return 1
    local cmd preview opts graph files target_commit prev_commit
    graph=--graph
    [[ $FORYADM_LOG_GRAPH_ENABLE == false ]] && graph=
    cmd="yadm log $graph --color=always --format='$foryadm_log_format' $* $foryadm_emojify"
    files=$(sed -nE 's/.* -- (.*)/\1/p' <<< "$*")
    preview="echo {} |grep -Eo '[a-f0-9]+' |head -1 |xargs -I% yadm show --color=always % -- $files | $foryadm_show_pager"
    opts="
        $FORYADM_FZF_DEFAULT_OPTS
        +s +m --tiebreak=index
        --bind=\"ctrl-y:execute-silent(echo {} |grep -Eo '[a-f0-9]+' | head -1 | tr -d '[:space:]' |${FORYADM_COPY_CMD:-pbcopy})\"
        $FORYADM_FIXUP_FZF_OPTS
    "
    target_commit=$(eval "$cmd" | FZF_DEFAULT_OPTS="$opts" fzf --preview="$preview" |
        grep -Eo '[a-f0-9]+' | head -1)
    if [[ -n "$target_commit" ]] && yadm commit --fixup "$target_commit"; then
        # "$target_commit~" is invalid when the commit is the first commit, but we can use "--root" instead
        if [[ "$(yadm rev-parse "$target_commit")" == "$(yadm rev-list --max-parents=0 HEAD)" ]]; then
            prev_commit="--root"
        else
            prev_commit="$target_commit~"
        fi
        # rebase will fail if there are unstaged changes so --autostash is needed to temporarily stash them
        # GIT_SEQUENCE_EDITOR=: is needed to skip the editor
        GIT_SEQUENCE_EDITOR=: yadm rebase --autostash -i --autosquash "$prev_commit"
    fi

}

# yadm checkout-file selector
foryadm::checkout::file() {
    foryadm::inside_work_tree || return 1
    [[ $# -ne 0 ]] && { yadm checkout -- "$@"; return $?; }
    local cmd files opts
    cmd="yadm diff --color=always -- {} | $foryadm_diff_pager"
    opts="
        $FORYADM_FZF_DEFAULT_OPTS
        -m -0
        $FORYADM_CHECKOUT_FILE_FZF_OPTS
    "
    files="$(yadm ls-files --modified "$(yadm rev-parse --show-toplevel)"| FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd")"
    [[ -n "$files" ]] && echo "$files" | tr '\n' '\0' | xargs -0 -I% yadm checkout %
}

# yadm checkout-branch selector
foryadm::checkout::branch() {
    foryadm::inside_work_tree || return 1
    [[ $# -ne 0 ]] && { yadm checkout -b "$@"; return $?; }
    local cmd preview opts
    cmd="yadm branch --color=always --verbose --all --format=\"%(if:equals=HEAD)%(refname:strip=3)%(then)%(else)%(refname:short)%(end)\" $foryadm_emojify | sed '/^$/d'"
    preview="yadm log {} --graph --pretty=format:'$foryadm_log_format' --color=always --abbrev-commit --date=relative"
    opts="
        $FORYADM_FZF_DEFAULT_OPTS
        +s +m --tiebreak=index
        $FORYADM_CHECKOUT_BRANCH_FZF_OPTS
        "
    eval "$cmd" | FZF_DEFAULT_OPTS="$opts" fzf --preview="$preview" | xargs -I% yadm checkout %
}

# yadm checkout-commit selector
foryadm::checkout::commit() {
    foryadm::inside_work_tree || return 1
    [[ $# -ne 0 ]] && { yadm checkout "$@"; return $?; }
    local cmd opts graph
    cmd="echo {} |grep -Eo '[a-f0-9]+' |head -1 |xargs -I% yadm show --color=always % | $foryadm_show_pager"
    opts="
        $FORYADM_FZF_DEFAULT_OPTS
        +s +m --tiebreak=index
        --bind=\"ctrl-y:execute-silent(echo {} |grep -Eo '[a-f0-9]+' | head -1 | tr -d '[:space:]' |${FORYADM_COPY_CMD:-pbcopy})\"
        $FORYADM_COMMIT_FZF_OPTS
    "
    graph=--graph
    [[ $FORYADM_LOG_GRAPH_ENABLE == false ]] && graph=
    eval "yadm log $graph --color=always --format='$foryadm_log_format' $foryadm_emojify" |
        FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd" |grep -Eo '[a-f0-9]+' |head -1 |xargs -I% yadm checkout % --
}

# yadm ignore generator
export FORYADM_GI_REPO_REMOTE=${FORYADM_GI_REPO_REMOTE:-https://github.com/dvcs/gitignore}
export FORYADM_GI_REPO_LOCAL="${FORYADM_GI_REPO_LOCAL:-${XDG_CACHE_HOME:-$HOME/.cache}/forgit/gi/repos/dvcs/gitignore}"
export FORYADM_GI_TEMPLATES=${FORYADM_GI_TEMPLATES:-$FORYADM_GI_REPO_LOCAL/templates}

foryadm::ignore() {
    [ -d "$FORYADM_GI_REPO_LOCAL" ] || foryadm::ignore::update
    local IFS cmd args opts
    cmd="$foryadm_ignore_pager $FORYADM_GI_TEMPLATES/{2}{,.gitignore} 2>/dev/null"
    opts="
        $FORYADM_FZF_DEFAULT_OPTS
        -m --preview-window='right:70%'
        $FORYADM_IGNORE_FZF_OPTS
    "
    # shellcheck disable=SC2206,2207
    IFS=$'\n' args=($@) && [[ $# -eq 0 ]] && args=($(foryadm::ignore::list | nl -nrn -w4 -s'  ' |
        FZF_DEFAULT_OPTS="$opts" fzf --preview="eval $cmd" | awk '{print $2}'))
    [ ${#args[@]} -eq 0 ] && return 1
    # shellcheck disable=SC2068
    foryadm::ignore::get ${args[@]}
}
foryadm::ignore::update() {
    if [[ -d "$FORYADM_GI_REPO_LOCAL" ]]; then
        foryadm::info 'Updating gitignore repo...'
        (cd "$FORYADM_GI_REPO_LOCAL" && yadm pull --no-rebase --ff) || return 1
    else
        foryadm::info 'Initializing gitignore repo...'
        yadm clone --depth=1 "$FORYADM_GI_REPO_REMOTE" "$FORYADM_GI_REPO_LOCAL"
    fi
}
foryadm::ignore::get() {
    local item filename header
    for item in "$@"; do
        if filename=$(find -L "$FORYADM_GI_TEMPLATES" -type f \( -iname "${item}.gitignore" -o -iname "${item}" \) -print -quit); then
            [[ -z "$filename" ]] && foryadm::warn "No gitignore template found for '$item'." && continue
            header="${filename##*/}" && header="${header%.gitignore}"
            echo "### $header" && cat "$filename" && echo
        fi
    done
}
foryadm::ignore::list() {
    find "$FORYADM_GI_TEMPLATES" -print |sed -e 's#.gitignore$##' -e 's#.*/##' | sort -fu
}
foryadm::ignore::clean() {
    setopt localoptions rmstarsilent
    [[ -d "$FORYADM_GI_REPO_LOCAL" ]] && rm -rf "$FORYADM_GI_REPO_LOCAL"
}

FORYADM_FZF_DEFAULT_OPTS="
$FZF_DEFAULT_OPTS
--ansi
--height='80%'
--bind='alt-k:preview-up,alt-p:preview-up'
--bind='alt-j:preview-down,alt-n:preview-down'
--bind='ctrl-r:toggle-all'
--bind='ctrl-s:toggle-sort'
--bind='?:toggle-preview'
--bind='alt-w:toggle-preview-wrap'
--preview-window='right:60%'
+1
$FORYADM_FZF_DEFAULT_OPTS
"

# register aliases
# shellcheck disable=SC2139
if [[ -z "$FORYADM_NO_ALIASES" ]]; then
    alias "${foryadm_add:-yadd}"='foryadm::add'
    alias "${foryadm_reset_head:-yadrh}"='foryadm::reset::head'
    alias "${foryadm_log:-yadlo}"='foryadm::log'
    alias "${foryadm_diff:-yadiff}"='foryadm::diff'
    alias "${foryadm_ignore:-yadi}"='foryadm::ignore'
    alias "${foryadm_checkout_file:-yadcf}"='foryadm::checkout::file'
    alias "${foryadm_checkout_branch:-yadcb}"='foryadm::checkout::branch'
    alias "${foryadm_checkout_commit:-yadco}"='foryadm::checkout::commit'
    alias "${foryadm_clean:-yadclean}"='foryadm::clean'
    alias "${foryadm_stash_show:-yadss}"='foryadm::stash::show'
    alias "${foryadm_cherry_pick:-yadcp}"='foryadm::cherry::pick'
    alias "${foryadm_rebase:-yadrb}"='foryadm::rebase'
    alias "${foryadm_fixup:-yadfu}"='foryadm::fixup'
fi
