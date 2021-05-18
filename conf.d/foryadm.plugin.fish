# MIT (c) Chris Apple

function foryadm::warn
    printf "%b[Warn]%b %s\n" '\e[0;33m' '\e[0m' "$argv" >&2;
end

function foryadm::info
    printf "%b[Info]%b %s\n" '\e[0;32m' '\e[0m' "$argv" >&2;
end

function foryadm::inside_work_tree
    yadm rev-parse --is-inside-work-tree >/dev/null;
end

set -g foryadm_pager        "$FORYADM_PAGER"
set -g foryadm_show_pager   "$FORYADM_SHOW_PAGER"
set -g foryadm_diff_pager   "$FORYADM_DIFF_PAGER"
set -g foryadm_ignore_pager "$FORYADM_IGNORE_PAGER"
set -g foryadm_log_format   "$FORYADM_LOG_FORMAT"

test -z "$foryadm_pager";        and set -g foryadm_pager        (yadm config core.pager || echo 'cat')
test -z "$foryadm_show_pager";   and set -g foryadm_show_pager   (yadm config pager.show || echo "$foryadm_pager")
test -z "$foryadm_diff_pager";   and set -g foryadm_diff_pager   (yadm config pager.diff || echo "$foryadm_pager")
test -z "$foryadm_ignore_pager"; and set -g foryadm_ignore_pager (type -q bat >/dev/null 2>&1 && echo 'bat -l gitignore --color=always' || echo 'cat')
test -z "$foryadm_log_format";   and set -g foryadm_log_format   "-%C(auto)%h%d %s %C(black)%C(bold)%cr%Creset"

# https://github.com/wfxr/emoji-cli
type -q emojify >/dev/null 2>&1 && set -g foryadm_emojify '|emojify'

# yadm commit viewer
function foryadm::log -d "yadm commit viewer"
    foryadm::inside_work_tree || return 1

    set files (echo $argv | sed -nE 's/.* -- (.*)/\1/p')
    set cmd "echo {} |grep -Eo '[a-f0-9]+' |head -1 |xargs -I% yadm show --color=always % -- $files | $foryadm_show_pager"

    if test -n "$FORYADM_COPY_CMD"
        set copy_cmd $FORYADM_COPY_CMD
    else
        set copy_cmd pbcopy
    end

    set opts "
        $FORYADM_FZF_DEFAULT_OPTS
        +s +m --tiebreak=index
        --bind=\"enter:execute($cmd |env LESS='-r' less)\"
        --bind=\"ctrl-y:execute-silent(echo {} |grep -Eo '[a-f0-9]+' | head -1 | tr -d '[:space:]' |$copy_cmd)\"
        $FORYADM_LOG_FZF_OPTS
    "

    if set -q FORYADM_LOG_GRAPH_ENABLE
        set graph "--graph"
    else
        set graph ""
    end

    eval "yadm log $graph --color=always --format='$foryadm_log_format' $argv $foryadm_emojify" |
        env FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd"
end

## yadm diff viewer
function foryadm::diff -d "yadm diff viewer" 
    foryadm::inside_work_tree || return 1
    if count $argv > /dev/null
        if yadm rev-parse "$1" > /dev/null 2>&1
            set commit "$1" && set files "$2"
        else
            set files "$argv"
        end
    end

    set repo (yadm rev-parse --show-toplevel)
    set cmd "echo {} |sed 's/.*]  //' | xargs -I% yadm diff --color=always $commit -- '$repo/%' | $foryadm_diff_pager"
    set opts "
        $FORYADM_FZF_DEFAULT_OPTS
        +m -0 --bind=\"enter:execute($cmd |env LESS='-r' less)\"
        $FORYADM_DIFF_FZF_OPTS
    "

    eval "yadm diff --name-only $commit -- $files*| sed -E 's/^(.)[[:space:]]+(.*)\$/[\1]  \2/'" | env FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd"
end

# yadm add selector
function foryadm::add -d "yadm add selector"
    foryadm::inside_work_tree || return 1
    # Add files if passed as arguments
    count $argv >/dev/null && yadm add "$argv" && yadm status --short && return

    set changed (yadm config --get-color color.status.changed red)
    set unmerged (yadm config --get-color color.status.unmerged red)
    set untracked (yadm config --get-color color.status.untracked red)

    set extract_file "
        sed 's/^[[:space:]]*//' |           # remove leading whitespace
        cut -d ' ' -f 2- |                  # cut the line after the M or ??, this leaves just the filename
        sed 's/.* -> //' |                  # for rename case
        sed -e 's/^\\\"//' -e 's/\\\"\$//'  # removes surrounding quotes
    "
    set preview "
        set file (echo {} | $extract_file)
        # exit
        if test (yadm status -s -- \$file | grep '^??') # diff with /dev/null for untracked files
            yadm diff --color=always --no-index -- /dev/null \$file | $foryadm_diff_pager | sed '2 s/added:/untracked:/'
        else
            yadm diff --color=always -- \$file | $foryadm_diff_pager
        end
        "
    set opts "
        $FORYADM_FZF_DEFAULT_OPTS
        -0 -m --nth 2..,..
        $FORYADM_ADD_FZF_OPTS
    "
    set files (yadm -c color.status=always -c status.relativePaths=true status -su |
        grep -F -e "$changed" -e "$unmerged" -e "$untracked" |
        sed -E 's/^(..[^[:space:]]*)[[:space:]]+(.*)\$/[\1]  \2/' |   # deal with white spaces internal to fname
        env FZF_DEFAULT_OPTS="$opts" fzf --preview="$preview" |
        sh -c "$extract_file") # for rename case

    if test -n "$files"
        for file in $files
            echo $file | tr '\n' '\0' | xargs -I{} -0 yadm add {}
        end
        yadm status --short
        return
    end
    echo 'Nothing to add.'
end

## yadm reset HEAD (unstage) selector
function foryadm::reset::head -d "yadm reset HEAD (unstage) selector"
    foryadm::inside_work_tree || return 1
    set cmd "yadm diff --cached --color=always -- {} | $foryadm_diff_pager"
    set opts "
        $FORYADM_FZF_DEFAULT_OPTS
        -m -0
        $FORYADM_RESET_HEAD_FZF_OPTS
    "
    set files (yadm diff --cached --name-only --relative | env FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd")
    if test -n "$files"
        for file in $files
            echo $file | tr '\n' '\0' |xargs -I{} -0 yadm reset -q HEAD {}
        end
        yadm status --short
        return
    end
    echo 'Nothing to unstage.'
end

# yadm checkout-restore selector
function foryadm::checkout::file -d "yadm checkout-file selector" --argument-names 'file_name'
    foryadm::inside_work_tree || return 1

    if test -n "$file_name"
        yadm checkout -- "$file_name"
        set checkout_status $status
        yadm status --short
        return $checkout_status
    end


    set cmd "yadm diff --color=always -- {} | $foryadm_diff_pager"
    set opts "
        $FORYADM_FZF_DEFAULT_OPTS
        -m -0
        $FORYADM_CHECKOUT_FILE_FZF_OPTS
    "
    set git_rev_parse (yadm rev-parse --show-toplevel)
    set files (yadm ls-files --modified "$git_rev_parse" | env FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd")

    if test -n "$files"
        for file in $files
            echo $file | tr '\n' '\0' | xargs -I{} -0 yadm checkout -q {}
        end
        yadm status --short
        return
    end
    echo 'Nothing to restore.'
end

function foryadm::checkout::commit -d "yadm checkout commit selector" --argument-names 'commit_id'
    foryadm::inside_work_tree || return 1

    if test -n "$commit_id"
        yadm checkout "$commit_id"
        set checkout_status $status
        yadm status --short
        return $checkout_status
    end

    if test -n "$FORYADM_COPY_CMD"
        set copy_cmd $FORYADM_COPY_CMD
    else
        set copy_cmd pbcopy
    end


    set cmd "echo {} |grep -Eo '[a-f0-9]+' |head -1 |xargs -I% yadm show --color=always % | $foryadm_show_pager"
    set opts "
        $FORYADM_FZF_DEFAULT_OPTS
        +s +m --tiebreak=index
        --bind=\"ctrl-y:execute-silent(echo {} |grep -Eo '[a-f0-9]+' | head -1 | tr -d '[:space:]' | $copy_cmd)\"
        $FORYADM_COMMIT_FZF_OPTS
    "

    if set -q FORYADM_LOG_GRAPH_ENABLE
        set graph "--graph"
    else
        set graph ""
    end

    eval "yadm log $graph --color=always --format='$foryadm_log_format' $foryadm_emojify" |
        FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd" |grep -Eo '[a-f0-9]+' |head -1 |xargs -I% yadm checkout % --
end


function foryadm::checkout::branch -d "yadm checkout branch selector" --argument-names 'branch_name'
    foryadm::inside_work_tree || return 1

    if test -n "$branch_name"
        yadm checkout -b "$branch_name"
        set checkout_status $status
        yadm status --short
        return $checkout_status
    end

    set cmd "yadm branch --color=always --verbose --all --format=\"%(if:equals=HEAD)%(refname:strip=3)%(then)%(else)%(refname:short)%(end)\" $argv $foryadm_emojify | sed '/^\$/d'"
    set preview "yadm log {} --graph --pretty=format:'$foryadm_log_format' --color=always --abbrev-commit --date=relative"

    set opts "
        $FORYADM_FZF_DEFAULT_OPTS
        +s +m --tiebreak=index 
        $FORYADM_CHECKOUT_BRANCH_FZF_OPTS
        "
    eval "$cmd" | env FZF_DEFAULT_OPTS="$opts" fzf --preview="$preview" | xargs -I% yadm checkout %
end

# yadm stash viewer
function foryadm::stash::show -d "yadm stash viewer"
    foryadm::inside_work_tree || return 1
    set cmd "echo {} |cut -d: -f1 |xargs -I% yadm stash show --color=always --ext-diff % |$foryadm_diff_pager"
    set opts "
        $FORYADM_FZF_DEFAULT_OPTS
        +s +m -0 --tiebreak=index --bind=\"enter:execute($cmd |env LESS='-r' less)\"
        $FORYADM_STASH_FZF_OPTS
    "
    yadm stash list | env FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd"
end

# yadm clean selector
function foryadm::clean -d "yadm clean selector"
    foryadm::inside_work_tree || return 1

    set opts "
        $FORYADM_FZF_DEFAULT_OPTS
        -m -0
        $FORYADM_CLEAN_FZF_OPTS
    "

    set files (yadm clean -xdffn $argv| awk '{print $3}'| env FZF_DEFAULT_OPTS="$opts" fzf |sed 's#/$##')

    if test -n "$files"
        for file in $files
            echo $file | tr '\n' '\0'| xargs -0 -I{} yadm clean -xdff {}
        end
        yadm status --short
        return
    end
    echo 'Nothing to clean.'
end

function foryadm::cherry::pick -d "yadm cherry-picking" --argument-names 'target'
    foryadm::inside_work_tree || return 1
    set base (yadm branch --show-current)
    if test -n "$target"
        echo "Please specify target branch"
        return 1
    end
    set preview "echo {1} | xargs -I% yadm show --color=always % | $foryadm_show_pager"
    set opts "
        $FORYADM_FZF_DEFAULT_OPTS
        -m -0
    "
    echo $base
    echo $target
    yadm cherry "$base" "$target" --abbrev -v | cut -d ' ' -f2- |
        env FZF_DEFAULT_OPTS="$opts" fzf --preview="$preview" | cut -d' ' -f1 |
        xargs -I% yadm cherry-pick %
end

function foryadm::fixup -d "yadm fixup"
    foryadm::inside_work_tree || return 1
    yadm diff --cached --quiet && echo 'Nothing to fixup: there are no staged changes.' && return 1

    if set -q FORYADM_LOG_GRAPH_ENABLE
        set graph "--graph"
    else
        set graph ""
    end

    set cmd "yadm log $graph --color=always --format='$foryadm_log_format' $argv $foryadm_emojify"
    set files (echo $argv | sed -nE 's/.* -- (.*)/\1/p')
    set preview "echo {} |grep -Eo '[a-f0-9]+' |head -1 |xargs -I% yadm show --color=always % -- $files | $foryadm_show_pager"

    if test -n "$FORYADM_COPY_CMD"
        set copy_cmd $FORYADM_COPY_CMD
    else
        set copy_cmd pbcopy
    end

    set opts "
        $FORYADM_FZF_DEFAULT_OPTS
        +s +m --tiebreak=index
        --bind=\"ctrl-y:execute-silent(echo {} |grep -Eo '[a-f0-9]+' | head -1 | tr -d '[:space:]' |$copy_cmd)\"
        $FORYADM_FIXUP_FZF_OPTS
    "

    set target_commit (eval "$cmd" | FZF_DEFAULT_OPTS="$opts" fzf --preview="$preview" | grep -Eo '[a-f0-9]+' | head -1)

    if test -n "$target_commit" && yadm commit --fixup "$target_commit"
        # "$target_commit~" is invalid when the commit is the first commit, but we can use "--root" instead
        set prev_commit "$target_commit~"
        if test "(yadm rev-parse '$target_commit')" = "(yadm rev-list --max-parents=0 HEAD)"
            set prev_commit "--root"
        end

        GIT_SEQUENCE_EDITOR=: yadm rebase --autostash -i --autosquash "$prev_commit"
    end

end


function foryadm::rebase -d "yadm rebase"
    foryadm::inside_work_tree || return 1

    if set -q FORYADM_LOG_GRAPH_ENABLE
        set graph "--graph"
    else
        set graph ""
    end
    set cmd "yadm log $graph --color=always --format='$foryadm_log_format' $argv $foryadm_emojify"

    set files (echo $argv | sed -nE 's/.* -- (.*)/\1/p')
    set preview "echo {} |grep -Eo '[a-f0-9]+' |head -1 |xargs -I% yadm show --color=always % -- $files | $foryadm_show_pager"

    if test -n "$FORYADM_COPY_CMD"
        set copy_cmd $FORYADM_COPY_CMD
    else
        set copy_cmd pbcopy
    end

    set opts "
        $FORYADM_FZF_DEFAULT_OPTS
        +s +m --tiebreak=index
        --bind=\"ctrl-y:execute-silent(echo {} |grep -Eo '[a-f0-9]+' | head -1 | tr -d '[:space:]' |$copy_cmd)\"
        $FORYADM_REBASE_FZF_OPTS
    "
    set commit (eval "$cmd" | FZF_DEFAULT_OPTS="$opts" fzf --preview="$preview" |
        grep -Eo '[a-f0-9]+' | head -1)

    if test $commit
        yadm rebase -i "$commit"
    end
end

# yadm ignore generator
if test -z "$FORYADM_GI_REPO_REMOTE"
    set -g FORYADM_GI_REPO_REMOTE https://github.com/dvcs/gitignore
end

if test -z "$FORYADM_GI_REPO_LOCAL"
    if test "XDG_CACHE_HOME"
        set -g FORYADM_GI_REPO_LOCAL $XDG_CACHE_HOME/forgit/gi/repos/dvcs/gitignore
    else
        set -g FORYADM_GI_REPO_LOCAL $HOME/.cache/forgit/gi/repos/dvcs/gitignore
    end
end

if test -z "$FORYADM_GI_TEMPLATES"
    set -g FORYADM_GI_TEMPLATES $FORYADM_GI_REPO_LOCAL/templates
end

function foryadm::ignore -d "yadm ignore generator"
    if not test -d "$FORYADM_GI_REPO_LOCAL"
        foryadm::ignore::update
    end

    set cmd "$foryadm_ignore_pager $FORYADM_GI_TEMPLATES/{2}{,.gitignore} 2>/dev/null"
    set opts "
        $FORYADM_FZF_DEFAULT_OPTS
        -m --preview-window='right:70%'
        $FORYADM_IGNORE_FZF_OPTS
    "
    set IFS '\n'

    set args $argv
    if not count $argv > /dev/null
        set args (foryadm::ignore::list | nl -nrn -w4 -s'  ' |
        env FZF_DEFAULT_OPTS="$opts" fzf --preview="$cmd"  |awk '{print $2}')
    end

     if not count $args > /dev/null
         return 1
     end

     foryadm::ignore::get $args
end

function foryadm::ignore::update
    if test -d "$FORYADM_GI_REPO_LOCAL"
        foryadm::info 'Updating gitignore repo...'
        set pull_result (yadm -C "$FORYADM_GI_REPO_LOCAL" pull --no-rebase --ff)
        test -n "$pull_result" || return 1
    else
        foryadm::info 'Initializing gitignore repo...'
        yadm clone --depth=1 "$FORYADM_GI_REPO_REMOTE" "$FORYADM_GI_REPO_LOCAL"
    end
end

function foryadm::ignore::get
    for item in $argv
        set filename (find -L "$FORYADM_GI_TEMPLATES" -type f \( -iname "$item.gitignore" -o -iname "$item}" \) -print -quit)
        if test -n "$filename"
            set header $filename && set header (echo $filename | sed 's/.*\.//')
            echo "### $header" && cat "$filename" && echo
        else
            foryadm::warn "No gitignore template found for '$item'." && continue
        end
    end
end

function foryadm::ignore::list
    find "$FORYADM_GI_TEMPLATES" -print |sed -e 's#.gitignore$##' -e 's#.*/##' | sort -fu
end

function foryadm::ignore::clean
    setopt localoptions rmstarsilent
    [[ -d "$FORYADM_GI_REPO_LOCAL" ]] && rm -rf "$FORYADM_GI_REPO_LOCAL"
end

set -g FORYADM_FZF_DEFAULT_OPTS "
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
if test -z "$FORYADM_NO_ALIASES"
    if test -n "$foryadm_add"
        alias $foryadm_add 'foryadm::add'
    else
        alias yada 'foryadm::add'
    end

    if test -n "$foryadm_reset_head"
        alias $foryadm_reset_head 'foryadm::reset::head'
    else
        alias yadrh 'foryadm::reset::head'
    end

    if test -n "$foryadm_log"
        alias $foryadm_log 'foryadm::log'
    else
        alias yadlo 'foryadm::log'
    end

    if test -n "$foryadm_diff"
        alias $foryadm_diff 'foryadm::diff'
    else
        alias yadd 'foryadm::diff'
    end

    if test -n "$foryadm_ignore"
        alias $foryadm_ignore 'foryadm::ignore'
    else
        alias yadi 'foryadm::ignore'
    end

    if test -n "$foryadm_checkout_file"
        alias $foryadm_checkout_file 'foryadm::checkout::file'
    else
        alias yadcf 'foryadm::checkout::file'
    end

    if test -n "$foryadm_checkout_branch"
        alias $foryadm_branch 'foryadm::checkout::branch'
    else
        alias yadcb 'foryadm::checkout::branch'
    end

    if test -n "$foryadm_clean"
        alias $foryadm_clean 'foryadm::clean'
    else
        alias yadclean 'foryadm::clean'
    end

    if test -n "$foryadm_stash_show"
        alias $foryadm_stash_show 'foryadm::stash::show'
    else
        alias yadss 'foryadm::stash::show'
    end

    if test -n "$foryadm_cherry_pick"
        alias $foryadm_cherry_pick 'foryadm::cherry::pick'
    else
        alias yadcp 'foryadm::cherry::pick'
    end

    if test -n "$foryadm_rebase"
        alias $foryadm_rebase 'foryadm::rebase'
    else
        alias yadrb 'foryadm::rebase'
    end

    if test -n "$foryadm_fixup"
        alias $foryadm_fixup 'foryadm::fixup'
    else
        alias yadfu 'foryadm::fixup'
    end

    if test -n "$foryadm_checkout_commit"
        alias $foryadm_checkout_commit 'foryadm::checkout::commit'
    else
        alias yadco 'foryadm::checkout::commit'
    end

end
