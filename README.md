# heroku-push

Push to Heroku without using Git.

## Installation

    $ heroku plugins:install https://github.com/ddollar/heroku-push

## Usage

#### deploy the current directory

    $ heroku push

#### deploy an arbitrary directory

    $ heroku push ~/myapp

#### deploy a git repo

    $ heroku push https://github.com/ddollar/anvil.git

#### use a custom buildpack (see https://buildpacks.heroku.com)

    $ heroku push -b heroku/nodejs

#### use a local directory as a buildpack

    $ heroku push -b ~/mybuildpack
