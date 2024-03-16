function git-deep-copy
  bash -c 'git branch -r | grep -v "\->" | while read remote; do git branch --track "${remote#origin/}" "$remote"; done'
  git fetch --all
  git pull --all
end
