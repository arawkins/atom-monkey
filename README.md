# Monkey2 for Atom

This package provides basic support for the [Monkey2 programming language](http://monkey2.monkey-x.com) in [Atom](http://atom.io).

## Features

**Compiler Integration**  
Configure and run mx2cc from within Atom. Easily set build options, assign a default target, and get build output.

**Syntax Highlighting**  
Highlighting for core language keywords.

**Autocompletion**  
Provides basic autocompletion via the autocomplete-plus package.


## Installation

1. Install the package via the Atom package manager.
2. In the packange settings, enter the
path to your Monkey2 installation (eg. /Users/your-username/monkey2).

## Compiler integration and Toolbar

![Toolbar Screenshot](https://github.com/arawkins/atom-monkey/blob/master/images/mx2cc-toolbar.png?raw=true "mx2cc toolbar")

The compiler options can all be set via the toolbar. The selected options will be used when building any file in the current
project.

If you have chosen a default target (see below), clicking the green arrow button
will build it. Otherwise, it will try to build whatever
file is currently active in the editor.

## Selecting targets

![Selecting target example](https://github.com/arawkins/atom-monkey/blob/master/images/target-selection.png?raw=true "choosing a target")

Right click on any monkey2 file in your project tree. Choose Monkey from
the context menu. You can **Set Default Target**, which will designate the
chosen file as the one to pass to the compiler by default. You can also choose **Clear Default Target**, which
will clear any target you have previously selected as the default and **Build Selected**,
which will immediately compile the selected file.

## Keyboard Shortcuts

By default this package uses the following keyboard shortcuts. I've used
SHIFT as a prefix to hopefully avoid conflicts with other common packages,
but feel free to re-map them to suit your needs.

* **SHIFT-F5**: Build default target file
* **SHIFT-F6**: Build current file
* **SHIFT-F9**: Toggle output window
* **SHIFT-ESCAPE**: Close output window

## Syntax Highlighting

Highlighting is based off of [@gingerbeardman](https://github.com/gingerbeardman)'s
[Monkey Textmate bundle](https://github.com/gingerbeardman/monkey.tmbundle),
which was later converted by [@frameland](https://github.com/frameland/).

It includes syntax highlighting for the basic language keywords.
Currently there is no highlighting for module keywords (ie. mojo stuff).

## Autocompletion

Autocompletion depends the autocomplete-plus package, which should be installed by
default in Atom. If not, you can install it via the package manager.

Once you have entered a path to your monkey installation (see Installation above),
the package will automatically parse your modules folder, as well as your local project tree for monkey2 files.
It will then try to provide autocompletion suggestions based on what it finds.

Currently it will ignore anything within a Private or Extern block. It also cannot parse the type of
variables assigned in the shorthand format `Local var:= Image.Load(...`, so to get autocompletion on
your variables, define their type explicitly, eg. `Local var:Image = Image.Load(...`

## TO DO

Below are planned (but not promised!) additions to the package. I'll do my
best to get these implemented at some point.

* Atom Linter integration
* Improving autocompletion

## Support

Please report any bugs or suggestions as github issues or in [this thread](http://monkey2.monkey-x.com/forums/topic/atom-package-for-monkey2/) on the monkey2 forums

## Contributing

Pull requests and other contributions are welcome.

## Monkey-X

This package was originally forked from [@frameland](https://github.com/frameland/)'s [Monkey-x package](https://github.com/frameland/atom-monkey). If you are coding with Monkey-X, that package
is the one you want. For more info, visit the official forums:
(http://www.monkey-x.com/Community/posts.php?topic=10505)
