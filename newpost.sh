#!usr/bin/env bash

PS1='Choose directory: '
options=("datastructs" "go" "vim")
select opt in "${options[@]}"
do
    case $opt in
        "datastructs")
            post_diretory=$opt
            break
            ;;
        "go")
            post_diretory=$opt
            break
            ;;
        "vim")
            post_diretory=$opt
            break
            ;;
    esac
done

read -p "POST NAME: " post_name
read -p "POST Description: " post_description
read -p "POST categories: " post_categories
read -p "POST Tags: " post_tags
file=$HOME/blog/content/posts/$post_diretory/$post_name.md

hugo new posts/$post_diretory/$post_name.md

sed -i "" "s/^description =.*/description = \"$post_description\"/g" "$file"
sed -i "" "s/^tags =.*/categories = [\"$post_tags\"]/g" "$file"
sed -i "" "s/^categories =.*/categories = [\"$post_categories\"]/g" "$file"

echo  "Generate new posts"

nvim content/posts/$post_diretory/$post_name.md
