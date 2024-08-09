# Cherry Peak
## I want the commits on the master branch after the specific COMMIT_HASH to be transferred to the NEW_BRANCH branch.

### Note: git changes and stage must be empty


> git checkout -b <NEW_BRANCH> <COMMIT_HASH>

> git checkout <NEW_BRANCH>

> git cherry-pick <COMMIT_HASH>..master

> git checkout master

> git reset --hard <COMMIT_HASH>
