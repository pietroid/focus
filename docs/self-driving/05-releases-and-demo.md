# Releases and the weekly demo

The strategy asks for two kinds of visibility. The machine produces one of
them on every merge, and a human produces the other once a week.

## Every merge is a release

`.github/workflows/release.yml` runs when a PR is merged into `main`.

1. It looks for a draft release tagged `pr-<number>`. The E2E run on each
   push to the PR's branch creates that draft or updates it, holding:
   - `video.mp4`, the whole Maestro run in Chrome, from launch to the last
     assertion;
   - `report.xml`, JUnit, one test case per flow;
   - `screenshots.zip`, the `takeScreenshot` frames each flow saves at its
     key moments.
2. It writes the release notes: the PR's title and description, who merged
   it, then the Maestro summary (a table of flows, pass or fail, and the
   commit they ran against).
3. It publishes the release under the tag `vYYYY.MM.DD-pr<number>`, on the
   merge commit, and marks it as latest.

If the PR has no draft, for example because E2E never ran on it, the release
is published anyway and says it has no recorded proof.

Every release therefore answers two questions: what changed, from the PR
description, and whether it works, from the video.

### Writing PR descriptions that make good releases

The PR description becomes the release notes word for word. Write it for
someone who will read it in a month:

- one sentence on what someone can now do that they could not before;
- what to look for in the video;
- anything that did not make it in.

## The weekly demo

Once a week, a human turns the week's releases into one demo for people who
have never seen Focus. Its job is to celebrate what was done and to show the
value in a way nobody needs explained.

The raw material is already there:

```bash
# This week's releases, newest first
gh release list --limit 30 --json tagName,name,publishedAt \
  --jq '.[] | select(.publishedAt > (now - 7*86400 | todate)) | "\(.publishedAt[:10])  \(.name)  (\(.tagName))"'

# Pull every video from one release
gh release download v2026.09.24-pr42 --pattern 'video.mp4' --dir demo/pr42
```

A way to put it together that works:

1. **Pick three moments at most.** Choose the changes that someone outside
   the project would notice. A refactor with no visible effect does not make
   the demo, however good it was.
2. **Before and after.** For each moment, show the old way in one sentence,
   then the new clip. Cut the release video down to the ten seconds that
   show the thing.
3. **Say it in the user's words.** Write "you can now write down something
   for later without giving it an hour", not "added things endpoint".
4. **Publish it** as a GitHub release of its own, tagged `demo-YYYY-WW`, with
   the cut video attached and links to the releases it covers. The page is
   public like the repository, so the link can go anywhere.

The weekly demo stays manual on purpose. Choosing what matters to someone
who has never seen the product is the part of this loop a human should own.
