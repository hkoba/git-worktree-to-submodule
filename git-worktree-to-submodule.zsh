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
o_dir=() 
zparseopts -D -K n=o_dryrun x=o_xtrace S=o_sourceonly d:=o_dir

#----------------------------------------

if (($#o_dir)); then
    outerGit=${${o_dir[2]}#=}
    # XXX: This must match (../)#
    outerGit=$(cd $outerGit && print $PWD)
else
    outerGit=$PWD
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
        if [[ ! -e .git/HEAD ]] || ! bra=$(git-current); then
            echo 1>&2 "Can't find current branch for $submod, skipped"
            return
        fi
        remote=$(get_default_remote)
        url=$(git config remote.$remote.url)
        relative-gitdir-and-smpath $destDn $PWD
        E git config -f $outerGit/.gitmodules submodule.$modName.path $modName
        E git config -f $outerGit/.gitmodules submodule.$modName.url $url
        E git config -f $outerGit/.git/config submodule.$modName.url $url
        E mv -v $PWD/.git $destDn
        ECHO-TO $PWD/.git gitdir: $gitdir
        E git config -f $destDn/config core.worktree $worktree
        E git add $PWD
    )
}

function git-current {
  local ref; ref=$(git symbolic-ref HEAD)
  [[ $ref = refs/heads/* ]] && print ${ref#refs/heads/}
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
        E git init
    fi
    if [[ ! -d .git/modules ]]; then
        E mkdir .git/modules
    fi
    for dn in "$@"; do
        gen-workdir-to-submodule . $dn
    done
    E git add .gitmodules
}

if (($#o_dryrun)); then
    main $outerGit "$@"
else
    main $outerGit "$@" | sh
fi