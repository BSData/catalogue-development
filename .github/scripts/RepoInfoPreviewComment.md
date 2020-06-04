**Repository name:** `{0}`
**Repository description:** `{1}`
**Collaborators to invite:** `{2}`

If you'd like to change either of these:
* **name** is taken from the first line of the issue body if it starts with a `name: ` prefix, or if it doesn't,
 by normalizing the **description** with some simple regex. To change, add a first line in format
 `name: example-repo-name` in the issue body.
* **description** is taken from the issue title, skipping `New Repo: ` prefix - to change, edit issue title.
* **collaborators** should include request author (OP).

Comment `/preview` to request this check again.

(**BSData organization owner only**): Comment `/approve` to create the new repository as shown above.
