#!/bin/sh

for lang in ja; do msgmerge --previous --update --lang=${lang} ${lang}/wesnoth-The_Earths_Gut.po TEG.pot; done
