# Patches

These are patches required to successfully build PrusaSlicer for ARM using the latest container images. To apply these
to your own tree/branch/repository, use:

    $ git apply /path/to/this/patches/dir/prusaslicer_version/*

# Generating a patch

When encountering an error, generate a patch by making changes and committing them in a clone of the PrusaSlicer repository:

```bash
git add file.txt
git commit -m 'Fixed an issue in file.txt'
git format-path 'HEAD^1'
0001-Fixed-an-issue-in-file.txt.patch
```

# Adding a patch

Add the patch file to/within this folder, with the tagged version of PrusaSlicer as the folder name. Running `build.sh` will then run `git apply -v` on the patch files within, applying them to the cloned PrusaSlicer repository.