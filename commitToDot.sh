#!/usr/bin/env bash

function gcommit {
    local sha=${1}

    # write commit node
    local message=$(git log --format=%B -n 1 ${sha})
    echo "\"${sha}\" [label=\"<c:${sha:0:7}>\n${message}\"];" >> ${commitsFile}

    #get and process tree
    local treeSha=$(git dump ${sha} | grep tree | awk '{print $2}')
    gtree ${treeSha}
    echo "\"${sha}\" -> \"${treeSha}\";" >> ${edgesFile}

    #get and process parents
    if [[ $(git dump ${sha} | grep parent) ]] ;then
        while read -r i; do
        local parentSha=${i}
        echo ${parentSha}
            gcommit ${parentSha}
            echo "\"${sha}\" -> \"${parentSha}\";" >> ${edgesFile}
        done <<< $(git dump ${sha} | grep parent | awk '{print $2}')
    fi
}

function gtree {
    local sha=${1}

    # write tree node
    echo "\"${sha}\" [label=\"<t:${sha:0:7}>\"];" >> ${treesFile}

    #get and process subs

    while read -r sub; do
        local subType=$(echo ${sub} | awk '{print $2}')
        local subSha=$(echo ${sub} | awk '{print $3}')
        local subName=$(echo ${sub} | awk '{print $4}')
        if [[ "${subType}" == "tree" ]]
        then
            gtree ${subSha}
        else
            gblob ${subSha}
        fi
        echo "\"${sha}\" -> \"${subSha}\" [label=\"${subName}\"];" >> ${edgesFile}
    done <<< $(git dump ${sha})
}

function gblob {
    local sha=${1}
    local content=$(git dump ${sha})

    # write tree node
    echo "${sha} [label=\"<b:${sha:0:7}>\n${content:0:15}...\"];" >> ${blobsFile}
}

edgesFile=/tmp/ctd_edges
rm -fr ${edgesFile}
commitsFile=/tmp/ctd_commits
rm -fr ${commitsFile}
treesFile=/tmp/ctd_trees
rm -fr ${treesFile}
blobsFile=/tmp/ctd_blobs
rm -fr ${blobsFile}
dotBuffer=/tmp/ctd_dotBuffer
rm -fr ${dotBuffer}

gcommit $(git rev-parse ${1})
output=${2}

cat > ${dotBuffer} << EOM
digraph {
    subgraph cluster_c {
    label = "Commits";
$(cat ${commitsFile} | sort | uniq)
    }

    subgraph cluster_t {
    label = "Trees";
$(cat ${treesFile} | sort | uniq)
    }
    subgraph cluster_b {
    label = "Blobs";
$(cat ${blobsFile} | sort | uniq)
    }
$(cat ${edgesFile} | sort | uniq)
}
EOM

dot -Tpng ${dotBuffer}>${output}