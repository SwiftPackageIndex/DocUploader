#!/bin/sh

set -eu

executable=$1

target=".lambda/$executable"

echo "Make Dir: $target"
mkdir -p "$target"

echo "Copy .build/release/$executable to $target/"
cp ".build/release/$executable" "$target/"

echo "Add the target deps based on ldd:"
ldd ".build/release/$executable" | grep swift | awk '{print $3}' | xargs cp -Lv -t "$target"

echo "Change directory: $target"
cd "$target"

echo "Link: $executable"
ln -s "$executable" "bootstrap"

echo "Zip:"
zip --symlinks "$executable.zip" *
