require_relative 'lib/pdfwalker/version'

Gem::Specification.new do |s|
    s.name          = "pdfwalker"
    s.version       = PDFWalker::VERSION
    s.author        = "Guillaume Delugré"
    s.email         = "origami@subvert.technology"
    s.homepage      = "http://github.com/gdelugre/pdfwalker"
    s.platform      = Gem::Platform::RUBY

    s.summary       = "a PDF document explorer"
    s.description   = "PDFWalker is a GTK frontend to explore the internals of a PDF document with Origami"

    s.files         = Dir[
                        'COPYING',
                        'lib/**/*'
                    ]

    s.require_path  = "lib"
    s.has_rdoc      = false
    s.license       = "GPL-3.0+"

    s.bindir        = "bin"
    s.executable    = 'pdfwalker'

    s.add_runtime_dependency "gtk2", "~> 3.1"
    s.add_runtime_dependency "ruby-gtkhex", "~> 0.2"
    s.add_runtime_dependency "origami", "~> 2.0"
end
