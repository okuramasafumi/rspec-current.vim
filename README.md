# rspec-current.vim

## Caution

It's very unstable. It's not documented yet and the implementation is immature. Feel free to try it but everything is subject to change in the future.

## Limitations

It required Ruby 3.2 since it uses new features added to `RubyVM::AbstractSyntaxTree` in Ruby 3.2.

## Usage

First, install `neovim` gem.

```sh
gem install neovim
```

Then install it with your favorite package manager. After installation, two functions are available.

* `RSpecCurrentSubject`: Returns current `subject` as a String
* `RSpecCurrentContext` Returns current `context` as a String

Then you can echo it with something like:

```vim
:echo RSpecCurrentSubject()
```

You can set these functions in your statusline plugin to track current subject/context.
