#!/usr/bin/env bash
set -e

SECONDS=0

if [ $# -eq 0 ]; then
    echo "Usage: replay-history.sh"
    echo "-n --num-commits     number of commits to replay"
    echo "-s --start-commit    SHA of commit to start from"
    echo "-t --timeout         timeout the script after X seconds"
    echo "-h --help            show this help message"
    exit 1
fi

for i in "$@"
do
case $i in
    -n=*|--num-commits=*)
    NUM_COMMITS="${i#*=}"
    shift # past argument=value
    ;;
    -s=*|--start-commit=*)
    START_COMMIT="${i#*=}"
    shift # past argument=value
    ;;
    -t=*|--timeout=*)
    TIME_OUT="${i#*=}"
    shift
    ;;
    -h|--help)
    echo "Usage: replay-history.sh"
    echo "-n --num-commits     number of commits to replay"
    echo "-s --start-commit    SHA of commit to start from"
    echo "-t --timeout         timeout the script after X seconds"
    echo "-h --help            show this help message"
    shift # past argument=value
    exit 1
    ;;
    *)
    echo "Unknown flag set ${i}"
    exit 1
          # unknown option
    ;;
esac
done

if [ -z ${NUM_COMMITS+x} ]; then
    echo "Number of commits not specified";
    exit 1
else
    echo "Replaying the last $NUM_COMMITS commits";
fi

set -x

mkdir source
cd source
repo init -u git://github.com/couchbase/manifest -m branch-master.xml
repo sync

cd kv_engine
git fetch http://review.couchbase.org/kv_engine refs/changes/42/87842/5
git fetch http://review.couchbase.org/kv_engine refs/changes/30/88030/3
git fetch http://review.couchbase.org/kv_engine refs/changes/09/87909/16
git fetch http://review.couchbase.org/kv_engine refs/changes/78/87878/8
git fetch http://review.couchbase.org/kv_engine refs/changes/64/88564/8
git fetch http://review.couchbase.org/kv_engine refs/changes/68/88568/6
git fetch http://review.couchbase.org/kv_engine refs/changes/64/88764/4
git fetch http://review.couchbase.org/kv_engine refs/changes/64/88864/4

if [ -z ${START_COMMIT+x} ]; then
    echo "Checking out $START_COMMIT"
    git checkout $START_COMMIT
fi
GIT_LOG=$(git --no-pager log --pretty=format:"%H~%cd" -n $NUM_COMMITS --reverse; echo)
IFS=$'\n';
cd ..

for OUTPUT in $GIT_LOG; do
    repo sync -j24 -d
    cd kv_engine
    export GERRIT_PATCHSET_REVISION=$(echo $OUTPUT | cut -f1 -d'~');
    COMMIT_DATE=$(echo $OUTPUT | cut -f2 -d'~');
    cd ..
    repo forall -c 'git checkout `git rev-list HEAD -n1 --before=$COMMIT_DATE`'
    cp -f tlm/CMakeLists.txt tlm/Makefile tlm/GNUmakefile .
    cd kv_engine
    export GERRIT_CHANGE_COMMIT_MESSAGE=$(python -c "import base64, sys; print base64.b64encode(sys.argv[1])" "$(git show ${GERRIT_PATCHSET_REVISION} --no-patch --format=%B)")
    if ! git merge-base --is-ancestor 7119049b4afa963e12b97cc172f6ba30e664eec1 HEAD 2> /dev/null;
        then git cherry-pick -n 7119049b4afa963e12b97cc172f6ba30e664eec1;
    fi
    if ! git merge-base --is-ancestor 2cf7ac31af486b278867ae19eff7e45525e81455 HEAD 2> /dev/null;
        then git cherry-pick -n 2cf7ac31af486b278867ae19eff7e45525e81455;
    fi
    if ! git merge-base --is-ancestor fb470b451f2f1fc6c798d595698de2e2b1a5f4a8 HEAD 2> /dev/null;
        then git cherry-pick -n fb470b451f2f1fc6c798d595698de2e2b1a5f4a8;
    fi
    if ! git merge-base --is-ancestor a41634456d8ca0e28aedec8ee5306f2c7531518c HEAD 2> /dev/null;
        then git cherry-pick -n a41634456d8ca0e28aedec8ee5306f2c7531518c;
    fi
    if ! git merge-base --is-ancestor 3547c1d03cd4c0ae1ec2a8dd3c99222eb89e0020 HEAD 2> /dev/null;
        then git cherry-pick -n 3547c1d03cd4c0ae1ec2a8dd3c99222eb89e0020;
    fi
    if ! git merge-base --is-ancestor 1f2ec746fad99952489636c6af9f1aded1f0ab12 HEAD 2> /dev/null;
        then git cherry-pick -n 1f2ec746fad99952489636c6af9f1aded1f0ab12;
    fi
    if ! git merge-base --is-ancestor e493d071e2cf9259247bb48f0961d5929a5c2d8e HEAD 2> /dev/null;
        then git cherry-pick -n e493d071e2cf9259247bb48f0961d5929a5c2d8e;
    fi
    if ! git merge-base --is-ancestor 0f3bfd2532c546442608447b0e9326dcbaf7a698 HEAD 2> /dev/null;
        then git cherry-pick -n 0f3bfd2532c546442608447b0e9326dcbaf7a698;
    fi
    cd ..
    make -j24
    export CBNT_MACHINE_NAME="KV-Engine-Perf-2"
    numactl --interleave=all lnt runtest "kv-engine" kv_engine/tests/cbnt_tests/cbnt_test_list.yml master --submit_url=http://172.23.122.48/submitRun -v --commit=1 --iterations=5
    make clean -j24

    if [ ${TIMEOUT+x} ]; then
        if [ $SECONDS -ge $TIMEOUT ]; then
            set +x
            echo "Timing out and cleaning up after $SECONDS seconds"
            cd ..
            rm -rf source
            exit 0
        fi
    fi
done

cd ..
rm -rf source