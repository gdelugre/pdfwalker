PDF Walker
=====
[![Gem version](https://badge.fury.io/rb/pdfwalker.svg)](http://rubygems.org/gems/pdfwalker)

Overview
--------

PDF Walker is a graphical tool to analyze the contents of PDF documents, based on [Origami](https://github.com/gdelugre/origami).

It can be used to explore the internal contents of a document:

- browse through the object tree, including object streams
- follow object references and view cross references
- search objects using regular expressions
- decode and extract streams
- locate page contents and form fields
- sign documents

![Main view](/img/screenshot.png)

Installation
------------

    $ gem install pdfwalker

Dependencies
------------

* [Origami][gem-origami]
* [Gtk2][gem-ruby-gtk2]
* [Gtkhex][gem-ruby-gtkhex]

[gem-origami]: https://rubygems.org/gems/origami
[gem-ruby-gtk2]: https://rubygems.org/gems/gtk2
[gem-ruby-gtkhex]: https://rubygems.org/gems/ruby-gtkhex

Licence
-------

PDF Walker is distributed under the [GPL3](COPYING) license.
