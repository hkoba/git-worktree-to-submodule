#!/bin/zsh

# This script creates following directory structure under $1.
# .
# ├── expected
# │   ├── A
# │   │   ├── a
# │   │   └── aa
# │   └── B
# │       ├── X
# │       │   ├── Y
# │       │   │   ├── y
# │       │   │   └── yy
# │       │   ├── x
# │       │   └── xx
# │       ├── b
# │       └── bb
# ├── got
# │   ├── A
# │   │   ├── a
# │   │   └── aa
# │   └── B
# │       ├── X
# │       │   ├── Y
# │       │   │   ├── y
# │       │   │   └── yy
# │       │   ├── x
# │       │   └── xx
# │       ├── b
# │       └── bb
# ├── repo
# │   ├── A.git
# │   ├── B.git
# │   ├── X.git
# │   ├── Y.git
# │   └── expected.git
# └── work
#     ├── A
#     │   ├── a
#     │   └── aa
#     └── B
#         ├── X
#         │   ├── Y
#         │   │   ├── y
#         │   │   └── yy
#         │   ├── x
#         │   └── xx
#         ├── b
#         └── bb

set -eu

function die { echo 1>&2 $*; exit 1 }

scriptName=$0
function usage {
    cat 1>&2 <<EOF
Usage: ${scriptName:t} DESTDIR
EOF
    exit 1
}

if ((! ARGC)); then
    usage
fi

[[ -d $1 ]] || die "No such directory: $1"
[[ -w $1 ]] || die "Not a writable directory: $1"

tmpDir=$(cd $1 && print $PWD)

dirList=($tmpDir/{repo,work,expected,got});
rm -rf $dirList;
mkdir $dirList;

for d in A B B/X B/X/Y; do
    rd=$tmpDir/repo/$d:t.git
    git init --bare $rd
    dn=$tmpDir/work/$d
    # mkdir -p $dn
    git clone $rd $dn || break
    t=$dn:t:l
    echo $t > $dn/$t
    echo $t$t > $dn/$t$t
    (cd $dn && git add *(.) && git commit -m init && git push)
done;

root=$tmpDir/expected
rootRepo=$tmpDir/repo/expected.git

git init --bare $rootRepo
git clone $rootRepo $root

(
    cd $root
    git submodule add ../A.git
    git submodule add ../B.git
    git commit -m submodule
)

(
    cd $tmpDir/expected/B
    git submodule add ../X.git
    git commit -m submodule
)

(
    cd $tmpDir/expected/B/X
    git submodule add ../Y.git
    git commit -m submodule
)

for d in expected/B/X/Y expected/B/X expected/B expected; do
(
    cd $tmpDir/$d
    if ! git diff --exit-code >/dev/null; then
        git add -u
        git commit -m "expected $d:t"
    fi
    git push
)
done

# ========================================
# Then clone and verify.
# ========================================

git clone --recurse-submodules $tmpDir/repo/expected.git $tmpDir/got

diff -N -u -r --exclude=.git $tmpDir/got $tmpDir/expected
