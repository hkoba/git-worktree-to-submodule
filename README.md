# git-worktree-to-submodule

This script converts existing git workdirs into submodules 
(and creates surrounding new repository).

## SYNOPSIS

Imagine you have two workdirs AA and BB like following, and eventually want them to be
converted to submodules.

```
% tree -F -L 2 -a AA BB
AA
├── .git/
│   ├── HEAD
│   ├── branches/
│   ├── :
│   └── refs/
└── aa
BB
├── .git/
│   ├── HEAD
│   ├── branches/
│   ├── :
│   └── refs/
└── bb
```

`git-worktree-to-submodule.zsh` does this (I hope;-)

```
% git-worktree-to-submodule.zsh AA BB
# some outputs...
A  .gitmodules
A  AA
A  BB
SUCCESS!
% tree -F -L 1 -a
.
├── .git/
├── .gitmodules
├── AA/
└── BB/

% tree -F -L 2 -a AA BB
AA
├── .git
└── aa
BB
├── .git
└── bb
```
