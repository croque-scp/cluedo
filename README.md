# cluedo
A murder mystery.

## Building

Pre-built distributions can be found in `dist/`, but you might want to build
the project yourself if you're interested in making changes to it.

You'll need Node.js and Python 3.

The following instructions will tell you how to build the project on Linux. If
you're using Windows, you're a bad person, and should consider creating a Linux
environment with either a VM or the Windows Subsystem for Linux (WSL). WSL2,
available with the Windows Insider Programme, makes all this a touch easier by
letting you use your normal Windows folders like `Documents/` and stuff in the
Linux environment.

### Setting up the Javascript environment

cluedo is built on Node.js, and you'll need that installed if you want to do
anything here.

Once Node is installed, verify that the output of `which node` and `which npm`
looks reasonable.

Set up the Node environment in your directory of choice:
```shell
git clone https://github.com/rossjrw/cluedo
cd cluedo
npm install
```

You'll also need Gulp:
```shell
sudo npm install -g gulp
which gulp
```

### Setting up the Python environment

A Python script is used to move the dialogue from `src/events.xlsx` into
something that the Javascript environment understands. You'll need a Python
environment to do this, but if you don't want to modify `events.xlsx`, then you
can skip all the Python stuff.

For Python environment management I recommend Miniconda, and these commands can
be run from any directory after it's installed:
```shell
conda create -n cluedo python=3.8
conda activate cluedo
```
You can create a Python environment some other way if you like, but this is the
best way, and all other ways are inferior.

If you used Conda with the `python=` option, you do not need to already have
Python installed in your system. Conda will handle that for you.

Then, from this project's directory, install cluedo's Python requirements into
your activated environment:
```shell
pip install -r requirements.txt
```
Should be good to go.

### Building from source

To build everything from source, run the following from the project's
directory:
```shell
gulp events
gulp js
gulp css
gulp static
```
`gulp events` generates a temporary Coffeescript file, which is then processed
by `gulp js`, so you have to do them in that order. The order of the rest
doesn't matter.

Or you can just do this, which will do all of that in one command:
```shell
gulp
```
This will completely rebuild everything from source.

If you didn't create a Python environment, `gulp events` won't work and
therefore `gulp` by itself won't work either. You'll have to run `gulp js`,
`gulp css` and `gulp static` by themselves. `gulp events` only generates
`src/js/events.temp.coffee`, and later `dist/events.js`, so if you already have that, you don't need it.
