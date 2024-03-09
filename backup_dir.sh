#!/usr/bin/env bash

# Check required dependencies
readonly DEPENDENCIES="du awk tar xz pv"
for dependency in ${DEPENDENCIES}; do
  if ! command -v "${dependency}" > /dev/null 2>&1; then
    echo "ERROR: command '${dependency}' not found" >&2
    exit 2
  fi
done


src="$1"
path=$(dirname $src)
name=$(basename $src)

total=$(du -sb "$src" | awk '{print $1}')

#time tar --use-compress-program pixz -cvf $name.tar.xz -C $path $name

#tar --use-compress-program pixz -cf - -C $path $name | (pv -p --timer --rate --bytes > $name.tar.xz)

#tar -cf - -C $path $name -P | pv -s $(du -sb $path | awk '{print $1}') | pixz -9 > $name.tar.xz  

# tar -I'pixz -9' -cf - -C $path $name -P | (pv -s $total > $name.tar.xz)
tar -I'xz -T0 -9' -cf - -C $path $name -P | pv -s $total > $name.tar.xz

#$tar -I'pixz -9' -cf $name.tar.xz -C $path $name | progress -m $1
