#!/bin/bash

shopt -s nullglob

base="${2%%@*}"
snap="${2##$base}"

function die () {
    echo "fatal: $1"; exit 1
}

function is-btrfs-vol () {
    test -d "$1" -a "$(ls -laid "$1" 2>/dev/null | cut -f1 -d' ')" = "256"
}

case $1 in
    c|create)
	parent="$(dirname "$base")"
	is-btrfs-vol "$parent" || die "$parent is not a btrfs volume"

	if [[ -n "$snap" ]]; then
	    is-btrfs-vol "$base" || die "$base is not a btrfs volume"
	    [[ -d "$base/.btrfs" ]] || btrfsctl -S ".btrfs" "$base"
	    btrfsctl -s "$base/.btrfs/${snap##@}" "$base"
	    find "$base/.btrfs/${snap##@}/" -type d -name .btrfs | while read dir; do
		rmdir "$dir"
	    done
	elif [[ ! -d "$base" ]]; then
	    btrfsctl -S "${base##$parent/}" "$parent"
	else
	    echo "$base already exists"
	fi
	;;
    l|list)
	is-btrfs-vol "$base" || die "$base not a btrfs volume"
	for snap in "$base/.btrfs/"*; do
	    echo "   ${snap##$base/.btrfs/}"
	done
	;;
    r|restore)
        [[ -z "${snap##@}" ]] && die "Please specify a snapshot"
        is-btrfs-vol "$base" && is-btrfs-vol "$base/.btrfs" && \
            is-btrfs-vol "$base/.btrfs/${snap##@}" || die "$base$snap is not a btrfs snapshot"
	parent="$(dirname "$base")"
	is-btrfs-vol "$base/.." || die "Can't restore root snapshots yet"
	tmp="$(mktemp -d -u "$parent/XXXXXXX")"
	btrfsctl -s "$tmp" "$base/.btrfs/${snap##@}"
	mv "$base/.btrfs" "$tmp/"
	btrfsctl -D "$(basename "$base")" "$(dirname "$base")"
	mv "$tmp" "$base"
        ;;
    d|destroy)
	if [[ -n "$snap" ]]; then
	    is-btrfs-vol "$base/.btrfs/${snap##@}" || die "$base$snap is not a btrfs snapshot"
	    btrfsctl -D "${snap##@}" "$base/.btrfs"
	    [[ -z "$(ls "$base/.btrfs/")" ]] && btrfsctl -D ".btrfs" "$base"
	elif [[ -d "$base" ]]; then
	    [[ -d "$base/.btrfs" ]] && btrfsctl -D ".btrfs" "$base"
	    btrfsctl -D "$(basename "$base")" "$(dirname "$base")"
	else
	    echo "$base not a directory"
	fi
	;;
esac
