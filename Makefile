.PHONY: build run preview test app open review clean

build:
	swift build

# `swift run` would build only the app, not the media helper it loads.
run: build
	.build/debug/AllSet

# Keeps the notch panel open for UI work: make preview TAB=system (home, tray, mixer or system)
TAB ?= home
preview: build
	.build/debug/AllSet -previewNotch $(TAB)

test: build
	swift test

app:
	./scripts/build-app.sh

open: app
	open build/AllSet.app

# The Themes hero stacked under its design reference: build/review/reference-vs-now.png
review:
	./scripts/review-hero.sh

clean:
	rm -rf .build build
