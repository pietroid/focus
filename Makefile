all: build_runner

build_runner:
	fvm flutter pub run build_runner build --delete-conflicting-outputs
