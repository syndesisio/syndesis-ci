#!/bin/bash

REPO=`git remote show origin | grep Push | awk -F "/" '{print $5}'`

if [ -z "$REPO" ]; then
	REPO=`git remote show origin | grep Push | awk -F "/" '{print $2}'`
fi

echo "Adding remote repository: orgin-via-ssh with url: git@github.com:syndesisio/$REPO"
git remote add origin-via-ssh git@github.com:syndesisio/$REPO || true
