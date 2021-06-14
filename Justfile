@_default:
    just -l
diff:
    mkdir -p diff
    diff -u conf.d/forgit.plugin.fish conf.d/foryadm.plugin.fish > diff/fish.patch && echo $? || true
    diff -u forgit.plugin.zsh foryadm.plugin.zsh > diff/zsh.patch && echo $? || true

patch:
    # You should commit before this to keep a 'backup'
    patch -u conf.d/foryadm.plugin.fish -i diff/fish.patch  && echo $? || true
    patch -u foryadm.plugin.zsh -i diff/zsh.patch  && echo $? || true
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
