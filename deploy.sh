#!/bin/bash

if [[ $(git status -s) ]]
then
    echo "The working directory is dirty. Please commit any pending changes."
    exit 1;
fi

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

echo "Deleting old publication"
rm -rf public
mkdir public
git worktree prune
rm -rf .git/worktrees/public/

echo "Checking out master branch into public"
git worktree add -B master public origin/master

echo "Removing existing files"
rm -rf public/*

echo "Generating site"
hugo # if using a theme, replace with `hugo -t <YOURTHEME>`

echo "Updating master branch"
# Go To Public folder and add changes to git.
cd public

# Add CNAME file
touch CNAME && echo 'blog.gopherhub.org' > CNAME

git add --all

# Commit changes.
msg="rebuilding site `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi
git commit -m "$msg"

# Push source.
git push -f origin master

# Come Back up to the Project Root
cd ..
