# Whitewash: whitelist-based HTML validator for Ruby
# (originally written for Samizdat project)
#
#   Copyright (c) 2002-2009  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'rbconfig'
require 'rexml/document'
require 'yaml'
require 'whitewash_rexml_attribute_patch'

class WhitewashError < RuntimeError; end

class Whitewash
  begin
    FORMATTER = REXML::Formatters::Default.new(true)   # enable IE hack

  rescue LoadError, NameError

    # backwards compatibility for Ruby versions without REXML::Formatters
    #
    class LegacyFormatter
      def write(node, output)
        return unless node.respond_to?(:write)
        node.write(output, -1, false, true)
      end
    end

    FORMATTER = LegacyFormatter.new
  end

  def Whitewash.default_whitelist
    unless found = PATH.find {|dir| File.readable?(File.join(dir, WHITELIST)) }
      raise RuntimeError, "Can't find default whitelist"
    end
    File.open(File.join(found, WHITELIST)) {|f| YAML.load(f.read.untaint) }
  end

  # _whitelist_ is expected to be loaded from xhtml.yaml.
  #
  # _tidypath_ is a file path to a binary or library of HTMLtidy. If it points
  # to a library (detected by .so in the file name), Ruby/Tidy DL-based wrapper
  # library will be used. If it's a binary, pipe will be used to filter HTML
  # through it. If none is supplied, known binary and library locations will be
  # tried, with preference given to the binary if both are found.
  #
  def initialize(whitelist = Whitewash.default_whitelist, tidypath = nil)
    @whitelist = whitelist
    set_tidy(tidypath)
  end

  attr_reader :xhtml

  CSS = Regexp.new(%r{
    \A\s*
    ([-a-z0-9]+) : \s*
    (?: (?: [-./a-z0-9]+ | \#[0-9a-f]+ | [0-9]+% ) \s* ) +
    \s*\z
  }xi).freeze

  def check_style(css, style)
    style.split(';').each do |s|
      return false unless
        s =~ CSS and css.include? $1
    end
    true
  end

  # compare elements and attributes with the whitelist
  #
  def sanitize_element(xml, whitelist = @whitelist, &p)
    if xml.name =~ /^_/ or not whitelist.keys.include?(xml.name)
      # doesn't work without xpath
      xml.document.delete_element(xml.xpath)
      return
    end

    if xml.has_attributes?
      attrs = whitelist['_common'].merge((whitelist[xml.name] or {}))
      xml.attributes.each_attribute do |a|
        unless attrs[a.name] === a.to_s
          xml.delete_attribute(a.name)
          next
        end

        # sanitize CSS in style="" attributes
        if 'style' == a.name and whitelist['_css'] and
          not check_style(whitelist['_css'], a.value)

          xml.delete_attribute(a.name)
          next
        end
      end
    end

    if xml.has_elements?   # recurse
      xml.elements.each {|e| sanitize_element(e, whitelist, &p) }
    end

    if block_given?
      yield xml
    end
  end

  # filter HTML through Tidy
  #
  def tidy(html)
    @tidy_binary ? tidy_pipe(html) : tidy_dl(html)
  end

  # Return sanitized HTML.
  #
  # If block is supplied, it will be invoked for each REXML::Element in the
  # sanitized HTML.
  #
  def sanitize(html, whitelist = @whitelist, &p)
    html = tidy(html)
    (html.nil? or html.empty?) and raise WhitewashError,
      "Invalid HTML detected"

    begin
      xml = REXML::Document.new(html).root
      xml = xml.elements['//html/body']
    rescue REXML::ParseException
      raise WhitewashError, "Invalid XHTML detected: " +
        $!.continued_exception.to_s.gsub(/\n.*/, '')
    end

    sanitize_element(xml, whitelist, &p)

    html = ''
    xml.each {|child| FORMATTER.write(child, html) }

    html
  end

  private

  PATH = [ '/etc/whitewash',
           File.join(Config::CONFIG['datadir'].untaint, 'whitewash'),
           '/usr/local/share/whitewash/' ]

  WHITELIST = 'whitelist.yaml'

  SO_PATH_PATTERN = Regexp.new(/\.so(?:\..+)?\z/).freeze

  def is_so?(path)
    path =~ SO_PATH_PATTERN and File.readable?(path)
  end

  def set_tidy(tidypath)
    if tidypath.nil?
      [ '/usr/bin/tidy',
        '/usr/local/bin/tidy',
        '/usr/lib/libtidy.so',
        '/usr/local/lib/libtidy.so'
      ].each {|path|
        if File.exists?(path)
          tidypath = path
          break
        end
      }
    end

    if is_so?(tidypath)
      require 'tidy'

      # workaround for memory leak in Tidy.path=
      Thread.exclusive do
        if not defined?(@@tidysopath) or tidypath != @@tidysopath
          Tidy.path = @@tidysopath = tidypath
        end
      end

      @tidy_binary = nil

    elsif File.executable?(tidypath)
      @tidy_binary = tidypath
    end

    require 'open3' if @tidy_binary
  end

  def tidy_dl(html)
    xml = Tidy.open(:quiet => true,
                    :show_warnings => false,
                    :show_errors => 1,
                    :output_xhtml => true,
                    :literal_attributes => true,
                    :preserve_entities => true,
                    :tidy_mark => false,
                    :wrap => 0,
                    :char_encoding => 'utf8'
    ) {|tidy| tidy.clean(html.to_s.untaint) }

    xml.taint
  end

  def tidy_pipe(html)
    stdin, stdout, stderr =
      Open3.popen3(@tidy_binary +
                   ' --quiet yes' +
                   ' --show-warnings no' +
                   ' --show-errors 1' +
                   ' --output-xhtml yes' +
                   ' --literal-attributes yes' +
                   ' --preserve-entities yes' +
                   ' --tidy-mark no' +
                   ' --wrap 0' +
                   ' --char-encoding utf8')

    stdin.write(html.to_s.untaint)
    stdin.close

    errors = stderr.read
    stderr.close

    xhtml = stdout.read
    stdout.close

    errors.nil? or errors.empty? or raise WhitewashError,
      "Invalid HTML detected: " + errors

    xhtml
  end
end
