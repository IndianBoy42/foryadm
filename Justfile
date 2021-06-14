@_default:
    just -l
diff:
    mkdir -p diff
    diff -u conf.d/forgit.plugin.fish conf.d/foryadm.plugin.fish > diff/fish.patch || true
    diff -u forgit.plugin.zsh foryadm.plugin.zsh > diff/zsh.patch || true

patch:
    # You should commit before this to keep a 'backup'
    patch -u conf.d/foryadm.plugin.fish -i diff/fish.patch  || true
    patch -u foryadm.plugin.zsh -i diff/zsh.patch  || true
    just rej

rej: # TODO: use normal find command
    $PAGER $(fd -IH rej)

new:
    cp conf.d/forgit.plugin.fish conf.d/foryadm.plugin.fish 
    cp forgit.plugin.zsh foryadm.plugin.zsh

update:
    just patch
    just diff
    git diff
