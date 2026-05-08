#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <branch>" >&2
  exit 1
fi

BRANCH="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_LIB="$REPO_ROOT/.lake/build/lib"

# Find the worktree for the given branch
WORKTREE_PATH=""
while IFS= read -r line; do
  # git worktree list output format: <path> <hash> [<branch>]
  if [[ "$line" =~ \[${BRANCH}\]$ ]]; then
    WORKTREE_PATH="$(echo "$line" | awk '{print $1}')"
    break
  fi
done < <(git -C "$REPO_ROOT" worktree list)

if [ -z "$WORKTREE_PATH" ]; then
  echo "Error: no worktree found for branch '$BRANCH'" >&2
  exit 1
fi

SOURCE_LIB="$WORKTREE_PATH/.lake/build/lib"
if [ ! -d "$SOURCE_LIB" ]; then
  echo "Error: build directory not found at $SOURCE_LIB" >&2
  exit 1
fi

# Copy main build lib
echo "Syncing cache from $SOURCE_LIB ..."
mkdir -p "$BUILD_LIB"
rsync -a --delete "$SOURCE_LIB/" "$BUILD_LIB/"

# Copy package build libs
SOURCE_PKGS="$WORKTREE_PATH/.lake/packages"
DEST_PKGS="$REPO_ROOT/.lake/packages"
if [ -d "$SOURCE_PKGS" ]; then
  for pkg_dir in "$SOURCE_PKGS"/*/; do
    pkg_name="$(basename "$pkg_dir")"
    src_lib="$pkg_dir.lake/build/lib"
    dst_lib="$DEST_PKGS/$pkg_name/.lake/build/lib"
    if [ -d "$src_lib" ]; then
      echo "Syncing package cache: $pkg_name ..."
      mkdir -p "$dst_lib"
      rsync -a --delete "$src_lib/" "$dst_lib/"
    fi
  done
fi

echo "Done."
