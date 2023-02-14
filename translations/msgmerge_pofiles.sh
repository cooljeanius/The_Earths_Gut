#!/bin/sh

# First, run wmlxgettext from your wesnoth tools directory like this:
# ./wmlxgettext --domain=wesnoth-The_Earths_Gut --directory=/Users/ericgallager/Library/Containers/org.wesnoth.Wesnoth/Data/Library/Application\ Support/Wesnoth_1.16/data/add-ons/The_Earths_Gut --recursive --warnall --no-sort-by-file -o /Users/ericgallager/Library/Containers/org.wesnoth.Wesnoth/Data/Library/Application\ Support/Wesnoth_1.16/data/add-ons/The_Earths_Gut/translations/TEG.pot
# (with edits to correct paths as necessary)

for mylang in ja; do
	msgmerge --previous --update --lang=${mylang} wesnoth-The_Earths_Gut/${mylang}.po TEG.pot;
	msgfmt -o wesnoth-The_Earths_Gut/${mylang}.mo wesnoth-The_Earths_Gut/${mylang}.po;
done
if test -e ~/Downloads/TEG_old.pot; then
	diff -u ~/Downloads/TEG_old.pot TEG.pot > TEG.pot.diff
fi
