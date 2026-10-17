.PHONY: build run preview test app open clean

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

clean:
	rm -rf .build build
