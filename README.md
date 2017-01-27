# git-worktree-to-submodule

This script converts existing git workdirs into submodules 
(and creates surrounding new repository to store them).
Since this is done by moving each `X/.git/` in workdirs into `.git/modules/X/`, this conversion is invisible to the outside of git. This script updates `.git/modules/X/config` and `X/.git` to point each other again.
Nested submodules such as `X/Y/.git` are also relocated.
This script automatically creates backup `.tgz` first (if missing).

If you worry about what this script does, you can use **dry-run** mode with option `-n`. With this mode, this script emits a shellscript to stdout.
So, you can examine what this script will do line-by-line and even rewrite them.


## SYNOPSIS

Imagine you have two workdirs AA and BB like following, and eventually want them to be
converted to submodules.

```
% tree -F -L 2 -a AA BB
AA
├── .git/
│   ├── HEAD
│   ├── :
│   └── refs/
└── aa
BB
├── .git/
│   ├── HEAD
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
