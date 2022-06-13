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

# Download latest Noto fonts from Google.
#
if [[ ! -d css/fonts ]] || [[ ! -d _includes ]]; then
	rm -rf css/fonts css/fonts.css css/fonts-print.css _includes
	mkdir -p css/fonts _includes
	(
		cd css/fonts

		for WOFF in $(cat ../_fonts.css | sed -e 's/^.*src:.*url(//;/^\s.*/d;/^[^h].*/d;s/).*//' | xargs); do
			curl -sS -L -O $WOFF
			echo "<link rel=\"preload\" href=\"/css/fonts/$(echo "$WOFF" | sed -e "s#.*/##")\" as=\"font\" type=\"font/woff2\" crossorigin>" >> ../../_includes/font-headers.html
		done
		cat ../_fonts.css | sed -e 's#url(https.*/#url(/css/fonts/#' > ../fonts.css

		for WOFF in $(cat ../_fonts-print.css | sed -e 's/^.*src:.*url(//;/^\s.*/d;/^[^h].*/d;s/).*//' | xargs); do
			curl -sS -L -O $WOFF
			echo "<link rel=\"prefetch\" href=\"/css/fonts/$(echo "$WOFF" | sed -e "s#.*/##")\" as=\"font\" type=\"font/woff2\" crossorigin>" >> ../../_includes/font-headers.html
		done
		cat ../_fonts-print.css | sed -e 's#url(https.*/#url(/css/fonts/#' > ../fonts-print.css
	)
fi

# Build the site using either system Jekyll (assume that our
# environment has installed the necessary gems automatically) or via
# bundler.
#
if [[ -n "$(which jekyll)" ]]; then
	jekyll build --profile
else
	if [[ ! -x "$(which bundler)" ]]; then
		gem install --user-install bundler
		export PATH="$(ruby -r rubygems -e 'puts Gem.user_dir')/bin:$PATH"
	fi
	if [[ ! -d vendor/bundle ]]; then
		bundle config set path vendor/bundle
		bundle install
	fi
	bundle exec jekyll build --profile
fi

# Wrap tables in a div in order to make them scrollable (without
# breaking accessibility).
#
find _site -type f -iname '*.html' -exec sed -i -e 's#<table>#<div class="table-wrapper"><table>#g;s#</table>#</table></div>#g' "{}" \;

# Use &mdash; instead of "-" as a separator for dates in post links.
#
find _site -type f \( -iname '*.html' -o -iname '*.xml' \) -exec sed -i -e 's#>\([0-9]\{4\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\) - \([^<>]\+\)#>\1-\2-\3 \&mdash; \4#g' "{}" \;

# Fix Dataview tags.
#
find _site -type f \( -iname '*.html' -o -iname '*.xml' \) -exec sed -i -e 's#author:: #<strong>author:</strong> #g' "{}" \;
find _site -type f \( -iname '*.html' -o -iname '*.xml' \) -exec sed -i -e 's#conditions:: #<strong>conditions:</strong> #g' "{}" \;
find _site -type f \( -iname '*.html' -o -iname '*.xml' \) -exec sed -i -e 's#date:: #<strong>date:</strong> #g' "{}" \;
find _site -type f \( -iname '*.html' -o -iname '*.xml' \) -exec sed -i -e 's#issue:: #<strong>issue:</strong> #g' "{}" \;
find _site -type f \( -iname '*.html' -o -iname '*.xml' \) -exec sed -i -e 's#location:: #<strong>location:</strong> #g' "{}" \;
find _site -type f \( -iname '*.html' -o -iname '*.xml' \) -exec sed -i -e 's#newsletter:: #<strong>newsletter:</strong> #g' "{}" \;
find _site -type f \( -iname '*.html' -o -iname '*.xml' \) -exec sed -i -e 's#photographer:: #<strong>photographer:</strong> #g' "{}" \;
find _site -type f \( -iname '*.html' -o -iname '*.xml' \) -exec sed -i -e 's#tags:: #<strong>tags:</strong> #g' "{}" \;
find _site -type f \( -iname '*.html' -o -iname '*.xml' \) -exec sed -i -e 's#volume:: #<strong>volume:</strong> #g' "{}" \;

# Fixing the data view tags, above, treats out atom feed the same
# as regular HTML. This will lead to an invalid feed, and thus
# needs to be fixed.
#
sed -i -e 's#<strong>#\&lt;strong>#g;s#</strong>#\&lt;/strong>#g' _site/atom.xml

# Make all URLs relative (required for most web3 hosting solutions).
#
if [[ ! -d node_modules ]]; then
	npm install
fi
(
	cd _site
	../node_modules/.bin/all-relative
)

# Minify: https://github.com/tdewolff/minify
#
# Current version: 2.9.22 (last checked 2021-11-14)
#
# It's too bad we need to cart this binary around as part of the
# repo, but Fleek doesn't support installing our own tools
# (otherwise we'd just `apt install minify`).
#
chmod +x _build/minify
cp -rf _site _site.original
rm -rf _site/*
(
	cd _site.original
	../_build/minify --all --recursive --sync --output ../_site .
)
rm -rf _site.original
