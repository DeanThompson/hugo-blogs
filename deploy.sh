#!/bin/bash

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

# Build the project. 
hugo -t greyshade

# Go To Public folder
cd public
# Add changes to git.
git add -A

# Commit changes.
msg="rebuilding site `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi
git commit -m "$msg"

# Push source and build repos.
echo -e "\033[0;32mCommit and push public repo...\033[0m"
git push origin master

# Come Back
cd ..

echo -e "\033[0;32mCommit and push blog repo...\033[0m"
git add -A
git commit -m "$msg"
git push origin master
