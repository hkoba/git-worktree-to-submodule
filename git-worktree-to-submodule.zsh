#!/bin/zsh
# -*- coding: utf-8 -*-

emulate -L zsh
set -eu

setopt err_return extended_glob

scriptName=$0

#----------------------------------------
function die { echo 1>&2 $*; exit 1 }

function usage {
    cat 1>&2 <<EOF
Usage: ${scriptName:t} [-n] [-d DIR] WORKDIR...

Converts WORKDIRs into git submodules of outer DIR.

Options:

-n          dryrun
-d   DIR
EOF
    exit 1
}


#----------------------------------------

o_dryrun=() o_xtrace=() o_sourceonly=()
o_quiet=() o_NO_BACKUP=()
o_dir=() 
zparseopts -D -K n=o_dryrun x=o_xtrace S=o_sourceonly q=o_quiet \
           B=o_NO_BACKUP \
           d:=o_dir

#----------------------------------------

if (($#o_dir)); then
    outerGit=${${o_dir[2]}#=}
    # XXX: This must match (../)#
    outerGit=$(cd $outerGit && print $PWD)
else
    outerGit=$PWD
fi

verbose=()
if ((! $#o_quiet)); then
    verbose=(-v)
fi

#----------------------------------------

function ECHO-TO { local to=$1; shift; print echo ">$to" "$@" }
function E { print -- $* }
function gen-workdir-to-submodule {
    local outerWork=$1 submod=$2
    (
        cd $submod
        modName=$PWD:t
        destDn=$outerGit/.git/modules/$modName
        if [[ ! -e .git/HEAD ]]; then
            echo 1>&2 "Can't find .git/HEAD for $submod, skipped"
            return 1
        fi
        remote=$(get_default_remote)
        url=$(git config remote.$remote.url)
        relative-gitdir-and-smpath $destDn $PWD
        E git config -f $outerGit/.gitmodules submodule.$modName.path $modName
        E git config -f $outerGit/.gitmodules submodule.$modName.url $url
        E git config -f $outerGit/.git/config submodule.$modName.url $url
        E mv $verbose $PWD/.git $destDn
        ECHO-TO $PWD/.git gitdir: $gitdir
        E git config -f $destDn/config core.worktree $worktree
        E git add $PWD
    )
}

function gen-rewrite-nested-submodule {
    local outerWork=$1 submod=$2
    (
        cd $submod
        modName=$PWD:t
        destDn=$outerGit/.git/modules/$modName
        
        for gitfn in $(find . -depth -mindepth 2 -name .git -type f); do
            gitfn=${gitfn#./}
            rel=${gitfn//[!\/]##/..}
            gitdir=$(sed -n 's/^gitdir: //p' $gitfn)
            # Remove leading part of .git/
            modsuf=${gitdir/*\/[^\/]#\/.git\//}
            # echo modsuf1=$modsuf

            # Replace intermediate '../.git/modules/' to 'modules/'
            modsuf=${modsuf//(\/|(#s))..\/.git\/modules\//modules\/}
            #echo modsuf2=$modsuf
            ; # for indentation
                
            # Fake gitdir since this script can be operating on reloacated copy!
            newdir=.git/modules/$modName/$modsuf

            ECHO-TO $PWD/$gitfn gitdir: $rel/$newdir
            E git config -f $outerGit/$newdir/config \
              core.worktree $PWD/$gitfn:h
        done
    )
}

#----------------------------------------
# Functions stolen and ported from git-parse-remote

get_default_remote () {
    local curr_branch origin
    curr_branch=$(git symbolic-ref -q HEAD)
    curr_branch=${curr_branch#refs/heads/}
    origin=$(git config --get branch.$curr_branch.remote)
    print ${origin:-origin}
}

#----------------------------------------
# extracted from git-submodule.sh:module_clone
function relative-gitdir-and-smpath {
    gitdir=$1 sm_path=$2
    local a b

    # These dir may not yet exist.
    a=$gitdir:a/
    b=$sm_path:a/
    while [[ ${a%%/*} == ${b%%/*} ]]; do
	a=${a#*/}
	b=${b#*/}
    done
    # Now chop off the trailing '/'s that were added in the beginning
    a=${a%/}
    b=${b%/}
    
    # gitdir: and core.worktree
    gitdir=${b//[!\/]##/..}/$a
    worktree=${a//[!\/]##/..}/$b
}

#----------------------------------------
# Development aid. Define functions and stop.
# use like: "source git-worktree-to-submodule.zsh -S"

if (($#o_sourceonly)); then
    set +e
    return
fi

#========================================

((ARGC)) || usage

if (($#o_xtrace)); then
     set -x
fi

#----------------------------------------

function main {
    local outerGit=$1; shift

    [[ -d $outerGit ]] ||
        die "Invalid directory for outer git: $outerGit"
    
    [[ -w $outerGit ]] ||
        die "Outer git is not writable: $outerGit"

    cd $outerGit
    E set -e
    E cd $outerGit
    if [[ ! -e .git ]]; then
        E git init $o_quiet
    fi
    if [[ ! -d .git/modules ]]; then
        E mkdir .git/modules
    fi
    for dn in "$@"; do
        if gen-workdir-to-submodule . $dn; then
            gen-rewrite-nested-submodule . $dn
        fi
    done
    E git add .gitmodules
}

# $outerGit is abspath here.

if (($#o_dryrun)); then
    main $outerGit "$@"
else
    backupFn=$outerGit.tgz
    if ((! $#o_NO_BACKUP)) && [[ ! -e $backupFn ]]; then
        if ((! $#o_quiet)); then
            echo Making backup $backupFn first...
        fi
        (cd $outerGit:h && tar zcf $backupFn $outerGit:t)
    fi
    # Create all script and then run it.
    sh =(main $outerGit "$@")
fi
