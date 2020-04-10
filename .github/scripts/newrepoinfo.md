**Repository name:** `{0}`
**Repository description:** `{1}`
**Collaborators to invite:** `{2}`

If you'd like to change either of these:
* _description_ is taken from the issue title, skipping `New Repo: ` prefix - to change, edit issue title.
* _name_ is taken from the first line of the issue body if it starts with `name: ` prefix, or if it doesn't,
 by normalizing the _description_ with some simple regex. To change, add a first line in format
 `name: example-repo-name` in the issue body.

Comment `.preview` to request this check again.

(**BSData organization owner only**): Comment `.approve` to create the new repository as shown above.
