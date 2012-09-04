# heroku-push

Push to Heroku without using Git.

## Installation

    $ heroku plugins:install https://github.com/ddollar/heroku-push

## Usage

    Usage: heroku push [SOURCE]

     deploy code to heroku

     if SOURCE is a local directory, the contents of the directory will be built
     if SOURCE is a git URL, the contents of the repo will be built
     if SOURCE is a tarball URL, the contents of the tarball will be built

     SOURCE will default to "."

     -b, --buildpack URL  # use a custom buildpack
