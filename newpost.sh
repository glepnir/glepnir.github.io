#!usr/bin/env bash

read -p "POST DIRECTORY: " post_diretory
read -p "POST NAME: " post_name
# read -p "POST Description: " post_description
# read -p "POST categories: " post_categories
# read -p "POST Tags: " post_tags
file=$HOME/blog/content/posts/$post_diretory/$post_name.md

hugo new posts/$post_diretory/$post_name.md

echo  "Generate new posts"

# nvim content/posts/$post_diretory/$post_name.md
