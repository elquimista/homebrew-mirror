## Mirror Homebrew Packages

### Usage

Get into the Docker container shell:
```sh
yarn docker-ssh
```

Inside the Docker container shell:
```sh
# Start downloading bottles for OS X Mavericks
bin/start bottles --os=mavericks

# Start downloading bottles for OS X El Capitan, macOS High Sierra, macOS Mojave
bin/start bottles --os=el_capitan,high_sierra,mojave

# Start downloading non-bottle packages
bin/start nonbottles
```

Files are downloaded into `./data/bottles/` and `./data/non-bottles/` respectively.
