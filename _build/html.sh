#!/usr/bin/env bash

# Check to make sure that we're running in the repository root.
#
if [[ ! -f _config.yml || ! -d .bin ]]; then
	echo "This script must be run from the repository root!"
	exit 1
fi

# Clean destination directory.
#
[[ -d _site ]] && rm -rf _site

# Create static avatar link.
#
cp $(grep -e '^icon:' _config.yml | sed -e 's/^icon: //') avatar.webp

# Build the site using either system Jekyll (assume that our
# environment has installed the necessary gems automatically) or via
# bundler.
#
if [[ -n "$(which jekyll)" ]]; then
	jekyll build --profile || exit 4
elif [[ -n "$(which bundle)" ]]; then
	bundle config set path vendor/bundle || exit 8
	bundle install || exit 3
	bundle exec jekyll build --profile || exit 16
else
	echo "Cannot find Bundler, and Jekyll does not seem to be installed."
	exit 32
fi

# Wrap tables in a div in order to make them scrollable (without
# breaking accessibility).
#
find _site -type f -iname '*.html' -exec sed -i -e 's#<table>#<div class="table-wrapper"><table>#g;s#</table>#</table></div>#g' "{}" \;

# Make all URLs relative (required for most web3 hosting solutions).
#
npm install
(
	cd _site
	../node_modules/.bin/all-relative
)

# Minify: https://github.com/tdewolff/minify
#
# Current version: 2.9.22 (last checked 2021-11-14)
#
# It's too bad we need to cart this binary around as part of the repo,
# but Fleek doesn't support installing our own tools (otherwise we'd
# just `apt install minify`).
#
chmod +x _build/minify
cp -rf _site _site.original
rm -rf _site/*
(
	cd _site.original
	../_build/minify --all --recursive --sync --output ../_site .
)
rm -rf _site.original
