# rspec-current.vim

## Caution

It's very unstable. It's not documented yet and the implementation is immature. Feel free to try it but everything is subject to change in the future.

## Usage

Install it with your favorite package manager. After installation, two functions are available.

* `RSpecCurrentSubject`: Returns current `subject` as a String
* `RSpecCurrentContext` Returns current `context` or `describe` as a String

Then you can echo it with something like:

```vim
:echo RSpecCurrentSubject()
```
