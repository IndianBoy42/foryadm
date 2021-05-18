<h1 align="center">💤 forgit</h1>
<p align="center">
    <em>Utility tool for using yadm interactively. Powered by <a href="https://github.com/junegunn/fzf">junegunn/fzf</a>.</em>
</p>

<p align="center">
    <a href="https://github.com/wfxr/forgit/actions">
        <img src="https://github.com/wfxr/forgit/workflows/ci/badge.svg"/>
    </a>
    <a href="https://wfxr.mit-license.org/2017">
        <img src="https://img.shields.io/badge/License-MIT-brightgreen.svg"/>
    </a>
    <a href="https://img.shields.io/badge/Shell-Bash%20%7C%20Zsh%20%7C%20Fish-blue">
        <img src="https://img.shields.io/badge/Shell-Bash%20%7C%20Zsh%20%7C%20Fish-blue"/>
    </a>
    <a href="https://github.com/unixorn/awesome-zsh-plugins">
        <img src="https://img.shields.io/badge/Awesome-zsh--plugins-d07cd0?logo=data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAABVklEQVRIS+3VvWpVURDF8d9CRAJapBAfwWCt+FEJthIUUcEm2NgIYiOxsrCwULCwktjYKSgYLfQF1JjCNvoMNhYRCwOO7HAiVw055yoBizvN3nBmrf8+M7PZsc2RbfY3AfRWeNMSVdUlHEzS1t6oqvt4n+TB78l/AKpqHrdwLcndXndU1WXcw50k10c1PwFV1fa3cQVzSR4PMd/IqaoLeIj2N1eTfG/f1gFVtQMLOI+zSV6NYz4COYFneIGLSdZSVbvwCMdxMsnbvzEfgRzCSyzjXAO8xlHcxMq/mI9oD+AGlhqgxjD93OVOD9TUuICdXd++/VeAVewecKKv2NPlfcHUAM1qK9FTnBmQvJjkdDfWzzE7QPOkAfZiEce2ECzhVJJPHWAfGuTwFpo365pO0NYjmEFr5Eas4SPeJfll2rqb38Z7/yaaD+0eNM3kPejt86REvSX6AamgdXkgoxLxAAAAAElFTkSuQmCC"/>
    </a>
    <a href="https://github.com/pre-commit/pre-commit">
        <img src="https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white" alt="pre-commit" />
    </a>
    <a href="https://github.com/wfxr/forgit/graphs/contributors">
        <img src="https://img.shields.io/github/contributors/wfxr/forgit" alt="Contributors"/>
    </a>
</p>

This tool is designed to help you use yadm more efficiently.
It's **lightweight** and **easy to use**.

### 📥 Installation

*Make sure you have [`fzf`](https://github.com/junegunn/fzf) installed.*

``` zsh
# for zplug
zplug 'wfxr/forgit'

# for zgen
zgen load 'wfxr/forgit'

# for antigen
antigen bundle 'wfxr/forgit'

# for fisher
fisher install wfxr/forgit

# for omf
omf install https://github.com/wfxr/forgit

# for zinit
zinit load wfxr/forgit

# manually
# Clone the repository and source it in your shell's rc file.
```

You can run the following command to try `forgit` without installing:

``` bash
# for bash / zsh
source <(curl -sSL git.io/forgit)
# for fish
source (curl -sSL git.io/forgit-fish | psub)
```

### 📝 Features

- **Interactive `yadm add` selector** (`ga`)

![screenshot](https://raw.githubusercontent.com/wfxr/i/master/forgit-ga.png)

- **Interactive `yadm log` viewer** (`glo`)

![screenshot](https://raw.githubusercontent.com/wfxr/i/master/forgit-glo.png)

*The log graph can be disabled by option `FORYADM_LOG_GRAPH_ENABLE` (see discuss in [issue #71](https://github.com/wfxr/forgit/issues/71)).*

- **Interactive `.gitignore` generator** (`gi`)

![screenshot](https://raw.githubusercontent.com/wfxr/i/master/forgit-gi.png)

- **Interactive `yadm diff` viewer** (`gd`)

- **Interactive `yadm reset HEAD <file>` selector** (`grh`)

- **Interactive `yadm checkout <file>` selector** (`gcf`)

- **Interactive `yadm checkout <branch>` selector** (`gcb`)

- **Interactive `yadm checkout <commit>` selector** (`gco`)

- **Interactive `yadm stash` viewer** (`gss`)

- **Interactive `yadm clean` selector** (`gclean`)

- **Interactive `yadm cherry-pick` selector** (`gcp`)

- **Interactive `yadm rebase -i` selector** (`grb`)

- **Interactive `yadm commit --fixup && yadm rebase -i --autosquash` selector** (`gfu`)

### ⌨  Keybinds

|                      Key                      | Action                    |
| :-------------------------------------------: | ------------------------- |
|               <kbd>Enter</kbd>                | Confirm                   |
|                <kbd>Tab</kbd>                 | Toggle mark and move up   |
|       <kbd>Shift</kbd> - <kbd>Tab</kbd>       | Toggle mark and move down |
|                 <kbd>?</kbd>                  | Toggle preview window     |
|         <kbd>Alt</kbd> - <kbd>W</kbd>         | Toggle preview wrap       |
|        <kbd>Ctrl</kbd> - <kbd>S</kbd>         | Toggle sort               |
|        <kbd>Ctrl</kbd> - <kbd>R</kbd>         | Toggle selection          |
|        <kbd>Ctrl</kbd> - <kbd>Y</kbd>         | Copy commit hash*         |
| <kbd>Ctrl</kbd> - <kbd>K</kbd> / <kbd>P</kbd> | Selection move up         |
| <kbd>Ctrl</kbd> - <kbd>J</kbd> / <kbd>N</kbd> | Selection move down       |
| <kbd>Alt</kbd> - <kbd>K</kbd> / <kbd>P</kbd>  | Preview move up           |
| <kbd>Alt</kbd> - <kbd>J</kbd> / <kbd>N</kbd>  | Preview move down         |

\* Available when the selection contains a commit hash.
For linux users `FORYADM_COPY_CMD` should be set to make copy work. Example: `FORYADM_COPY_CMD='xclip -selection clipboard'`.

### ⚙  Options

#### aliases

You can change the default aliases by defining these variables below.
(To disable all aliases, Set the `FORYADM_NO_ALIASES` flag.)

``` bash
foryadm_log=yadlo
foryadm_diff=yadiff
foryadm_add=yadd
foryadm_reset_head=yadrh
foryadm_ignore=yadi
foryadm_checkout_file=yadcf
foryadm_checkout_branch=yadcb
foryadm_checkout_commit=yadco
foryadm_clean=yadclean
foryadm_stash_show=yadss
foryadm_cherry_pick=yadcp
foryadm_rebase=yadrb
foryadm_fixup=yadfu
```

#### pagers

Foryadm will use the default configured pager from yadm (`core.pager`,
`pager.show`, `pager.diff`) but can be altered with the following environment
variables:

| Use case             | Option                 | Fallbacks to                                   |
| -------------------- | ---------------------- | ---------------------------------------------- |
| common pager         | `FORYADM_PAGER`        | `yadm config core.pager` _or_ `cat`            |
| pager on `yadm show` | `FORYADM_SHOW_PAGER`   | `yadm config pager.show` _or_ `$FORYADM_PAGER` |
| pager on `yadm diff` | `FORYADM_DIFF_PAGER`   | `yadm config pager.diff` _or_ `$FORYADM_PAGER` |
| pager on `gitignore` | `FORYADM_IGNORE_PAGER` | `bat -l gitignore --color always` _or_ `cat`   |
| yadm log format      | `FORYADM_GLO_FORMAT`   | `%C(auto)%h%d %s %C(black)%C(bold)%cr%reset`   |

#### fzf options

You can add default fzf options for `forgit`, including keybinds, layout, etc.
(No need to repeat the options already defined in `FZF_DEFAULT_OPTS`)

``` bash
FORYADM_FZF_DEFAULT_OPTS="
--exact
--border
--cycle
--reverse
--height '80%'
"
```

Customizing fzf options for each command individually is also supported:

| Command  | Option                             |
| -------- | ---------------------------------- |
| `ga`     | `FORYADM_ADD_FZF_OPTS`             |
| `glo`    | `FORYADM_LOG_FZF_OPTS`             |
| `gi`     | `FORYADM_IGNORE_FZF_OPTS`          |
| `gd`     | `FORYADM_DIFF_FZF_OPTS`            |
| `grh`    | `FORYADM_RESET_HEAD_FZF_OPTS`      |
| `gcf`    | `FORYADM_CHECKOUT_FILE_FZF_OPTS`   |
| `gcb`    | `FORYADM_CHECKOUT_BRANCH_FZF_OPTS` |
| `gco`    | `FORYADM_CHECKOUT_COMMIT_FZF_OPTS` |
| `gss`    | `FORYADM_STASH_FZF_OPTS`           |
| `gclean` | `FORYADM_CLEAN_FZF_OPTS`           |
| `grb`    | `FORYADM_REBASE_FZF_OPTS`          |
| `gfu`    | `FORYADM_FIXUP_FZF_OPTS`           |

Complete loading order of fzf options is:

1. `FZF_DEFAULT_OPTS` (fzf global)
2. `FORYADM_FZF_DEFAULT_OPTS` (foryadm global)
3. `FORYADM_CMD_FZF_OPTS` (command specific)

Examples:

- `ctrl-d` to drop the selected stash but do not quit fzf (`gss` specific).
```
FORYADM_STASH_FZF_OPTS='
--bind="ctrl-d:reload(yadm stash drop $(cut -d: -f1 <<<{}) 1>/dev/null && yadm stash list)"
'
```

- `ctrl-e` to view the logs in a vim buffer (`glo` specific).
```
FORYADM_LOG_FZF_OPTS='
--bind="ctrl-e:execute(echo {} |grep -Eo [a-f0-9]+ |head -1 |xargs yadm show |vim -)"
'
```
#### other options

| Option               | Description     | Default                                       |
| -------------------- | --------------- | --------------------------------------------- |
| `FORYADM_LOG_FORMAT` | yadm log format | `%C(auto)%h%d %s %C(black)%C(bold)%cr%Creset` |

### 📦 Optional dependencies

- [`delta`](https://github.com/dandavison/delta) / [`diff-so-fancy`](https://github.com/so-fancy/diff-so-fancy): For better human readable diffs.

- [`bat`](https://github.com/sharkdp/bat.git): Syntax highlighting for `gitignore`.

- [`emoji-cli`](https://github.com/wfxr/emoji-cli): Emoji support for `yadm log`.

### 💡 Tips

- Most of the commands accept optional arguments (eg, `glo develop`, `glo f738479..188a849b -- main.go`, `gco master`).
- `gd` supports specifying revision(eg, `gd HEAD~`, `gd v1.0 README.md`).
- Call `gi` with arguments to get the wanted `.gitignore` contents directly(eg, `gi cmake c++`).
- You can use the commands as sub-commands of `git`, see [#147](https://github.com/wfxr/forgit/issues/147) for details.

### 📃 License

[MIT](https://wfxr.mit-license.org/2017) (c) Wenxuan Zhang
