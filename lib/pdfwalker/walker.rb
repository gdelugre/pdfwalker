#!/usr/bin/env ruby

=begin

    This file is part of PDF Walker, a graphical PDF file browser
    Copyright (C) 2017	Guillaume Delugré.

    PDF Walker is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    PDF Walker is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with PDF Walker.  If not, see <http://www.gnu.org/licenses/>.

=end

require 'origami'
require 'gtk2'

include Gtk

require_relative 'menu'
require_relative 'version'
require_relative 'about'
require_relative 'file'
require_relative 'hexview'
require_relative 'treeview'
require_relative 'textview'
require_relative 'imgview'
require_relative 'config'
require_relative 'properties'
require_relative 'xrefs'
require_relative 'signing'

module PDFWalker  #:nodoc:all

    class Walker < Window
        attr_reader :treeview, :hexview, :objectview
        attr_reader :explorer_history
        attr_reader :config
        attr_reader :filename

        def self.start(file = nil)
            Gtk.init
            Walker.new(file)
            Gtk.main
        end

        def initialize(target_file = nil)
            super("PDF Walker")

            @config = Walker::Config.new
            @opened = nil

            @last_search_result = []
            @last_search =
            {
                :expr => "",
                :regexp => false,
                :type => :body
            }

            @explorer_history = []

            init_interface

            open(target_file)
        end

        def error(msg)
            dialog = Gtk::MessageDialog.new(self,
                        Gtk::Dialog::DESTROY_WITH_PARENT,
                        Gtk::MessageDialog::ERROR,
                        Gtk::MessageDialog::BUTTONS_CLOSE,
                        msg
                     )

            dialog.run
            dialog.destroy
        end

        def reload
            @treeview.load(@opened) if @opened
        end

        def search
            dialog = Gtk::Dialog.new("Search...",
                        self,
                        Gtk::Dialog::MODAL | Gtk::Dialog::DESTROY_WITH_PARENT,
                        [Gtk::Stock::FIND, Gtk::Dialog::RESPONSE_OK],
                        [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL]
            )

            entry = Gtk::Entry.new
            entry.signal_connect('activate') { dialog.response(Gtk::Dialog::RESPONSE_OK) }
            entry.text = @last_search[:expr]

            button_bydata = Gtk::RadioButton.new("In object body")
            button_byname = Gtk::RadioButton.new(button_bydata, "In object name")
            button_regexp = Gtk::CheckButton.new("Regular expression")

            button_bydata.set_active(true) if @last_search[:type] == :body
            button_byname.set_active(true) if @last_search[:type] == :name
            button_regexp.set_active(@last_search[:regexp])

            hbox = Gtk::HBox.new
            hbox.pack_start Gtk::Label.new("Search for expression ")
            hbox.pack_start entry

            dialog.vbox.pack_start(hbox)
            dialog.vbox.pack_start(button_bydata)
            dialog.vbox.pack_start(button_byname)
            dialog.vbox.pack_end(button_regexp)

            dialog.signal_connect('response') do |_, response|
                if response != Gtk::Dialog::RESPONSE_OK
                    dialog.destroy
                    next
                end

                search_document(entry.text, regexp: button_regexp.active?, type: (button_bydata.active? ? 'body' : 'name'))
            end

            dialog.show_all
        end

        def goto_catalog
            @treeview.goto(@opened.Catalog.reference)
        end

        def goto_docinfo
            @treeview.goto(@opened.document_info.reference) if @opened.document_info?
        end

        def goto_metadata
            @treeview.goto(@opened.Catalog.Metadata.reference) if @opened.metadata?
        end

        def goto_object
            dialog = Gtk::Dialog.new("Jump to object...",
                        self,
                        Gtk::Dialog::MODAL | Gtk::Dialog::DESTROY_WITH_PARENT,
                        [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK],
                        [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL]
            )

            entry = Gtk::Entry.new
            entry.signal_connect('activate') { dialog.response(Gtk::Dialog::RESPONSE_OK) }

            dialog.vbox.pack_start Gtk::Label.new("Object number: ")
            dialog.vbox.pack_start entry
            dialog.show_all

            no = 0
            dialog.run do |response|
                no = entry.text.to_i if response == Gtk::Dialog::RESPONSE_OK

                dialog.destroy
            end

            return unless no > 0

            obj = @opened[no]
            if obj.nil?
                error("Object #{no} not found.")
            else
                @treeview.goto(obj)
            end
        end

        private

        def init_interface
            signal_connect('destroy') {
                @config.save
                Gtk.main_quit
            }

            add_events(Gdk::Event::KEY_RELEASE_MASK)
            signal_connect('key_release_event') { |_w, event|
                if event.keyval == Gdk::Keyval::GDK_F1 then about
                elsif event.keyval == Gdk::Keyval::GDK_Escape and @opened and not @explorer_history.empty?
                    @treeview.goto(@explorer_history.pop)
                end
            }

            create_menus
            create_treeview
            create_hexview
            create_objectview
            create_panels
            create_statusbar

            @vbox = Gtk::VBox.new
            @vbox.pack_start(@menu, false, false)
            @vbox.pack_start(@hpaned)
            @vbox.pack_end(@statusbar, false, false)

            add @vbox

            set_default_size(self.screen.width * 0.5, self.screen.height * 0.5)
            show_all
        end

        def search_document(expr, regexp: false, type: 'body')
            search =
            {
                expr: expr,
                regexp: regexp,
                type: type,
            }

            if search == @last_search
                @last_search_result.push @last_search_result.shift
                results = @last_search_result
            else
                expr = Regexp.new(expr) if search[:regexp]

                results =
                    if search[:type] == 'body'
                        @opened.grep(expr)
                    else
                        @opened.ls(expr, follow_references: false)
                    end

                @last_search = search
            end

            goto_next_search_result(results)
        end

        def goto_next_search_result(results)
            if results.empty?
                error("No result found.")
            else
                if results != @last_search_result
                    # Reset the previous search highlighting.
                    @last_search_result.each do |obj| @treeview.highlight(obj, nil) end

                    # Highlight the new results.
                    results.each do |obj| @treeview.highlight(obj, "lightpink") end

                    @last_search_result = results
                end

                @treeview.goto(results.first, follow_references: false)
            end
        end

        def create_panels
            @hpaned = Gtk::HPaned.new

            @treepanel = Gtk::ScrolledWindow.new.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
            @treepanel.add @treeview

            @vpaned = Gtk::VPaned.new
            @vpaned.pack1(@objectview, true, false)
            @vpaned.pack2(@hexview, true, false)

            @hpaned.pack1(@treepanel, true, false)
            @hpaned.pack2(@vpaned, true, false)
        end

        def create_statusbar
            @statusbar = Gtk::Statusbar.new

            @main_context = @statusbar.get_context_id 'Main'
            @statusbar.push(@main_context, 'No file selected')
        end

        def start_profiling
            if @help_menu_profile.active?
                require 'ruby-prof'
                RubyProf.start
            end

            result = yield

            if @help_menu_profile.active?
                result = RubyProf.stop
                multiprinter = RubyProf::MultiPrinter.new(result)

                Dir.mkdir(@config.profile_output_dir) unless Dir.exist?(@config.profile_output_dir) 

                multiprinter.print(path: @config.profile_output_dir, profile: File.basename(filename))
            end

            result
        end
    end

end

PDFWalker::Walker.start if __FILE__ == $0
