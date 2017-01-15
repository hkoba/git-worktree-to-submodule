#!/bin/zsh

binDir=$(cd $0:h && print $PWD)
appName=$binDir:h:t

tmpDir=${TMPPREFIX}-$appName-$$

{
    set -e

    mkdir -p $tmpDir

    $binDir/mktesttree.zsh $tmpDir >/dev/null

    cd $tmpDir

    gitopts=(-q)

    mkdir -p converted
    git clone $gitopts repo/A.git converted/A
    git clone $gitopts repo/B.git converted/B
    (cd converted/B && git submodule $gitopts update --init --recursive)
    
    (
        cd converted
        $binDir:h/$appName.zsh -q A B
    )
    
    if diff -N -u -r --exclude=.git --exclude=.gitmodules expected converted; then
        echo ok 1 - no difference
    else
        echo not ok 1 - difference found between expected and converted
    fi
    echo 1..1

} always {
    rm -rf $tmpDir
}
