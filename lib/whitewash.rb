# Whitewash: whitelist-based HTML validator for Ruby
# (originally written for Samizdat project)
#
#   Copyright (c) 2002-2011  Dmitry Borodaenko <angdraug@debian.org>
#
#   This program is free software.
#   You can distribute/modify this program under the terms of
#   the GNU General Public License version 3 or later.
#
# vim: et sw=2 sts=2 ts=8 tw=0

require 'rbconfig'
require 'nokogiri'
require 'yaml'

class WhitewashError < RuntimeError; end

class Whitewash

  if RUBY_VERSION < '1.9.3'
    def Whitewash.load(string)
      YAML.load(string)
    end

  else
    # use Syck to parse the whitelist until Psych issue #36 is fixed
    #
    def Whitewash.load(string)
      Mutex.new.synchronize do
        yamler = YAML::ENGINE.yamler
        YAML::ENGINE.yamler = 'syck'
        whitelist = YAML.load(string)
        YAML::ENGINE.yamler = yamler
        whitelist
      end
    end
  end

  def Whitewash.default_whitelist
    unless found = PATH.find {|dir| File.readable?(File.join(dir, WHITELIST)) }
      raise RuntimeError, "Can't find default whitelist"
    end
    File.open(File.join(found, WHITELIST)) {|f| Whitewash.load(f.read.untaint) }
  end

  # _whitelist_ is expected to be loaded from xhtml.yaml.
  #
  def initialize(whitelist = Whitewash.default_whitelist)
    @whitelist = whitelist
  end

  attr_reader :xhtml

  CSS = Regexp.new(%r{
    \A\s*
    ([-a-z0-9]+) : \s*
    (?: (?: [-./a-z0-9]+ | \#[0-9a-f]+ | [0-9]+% ) \s* ) +
    \s*\z
  }xi).freeze

  def check_style(whitelist, style)
    css = whitelist['_css'] or return true
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
      xml.element_children.each {|e| sanitize_element(e, whitelist, &p) }
      xml.replace(xml.children)
      return
    end

    # sanitize CSS in <style> elements
    if 'style' == xml.name and not check_style(whitelist, xml.content)
      xml.remove
      return
    end

    xml.attribute_nodes.each do |a|
      attrs ||= whitelist['_common'].merge((whitelist[xml.name] or {}))
      unless attrs[a.name] === a.to_s
        xml.remove_attribute(a.name)
        next
      end

      # sanitize CSS in style="" attributes
      if 'style' == a.name and not check_style(whitelist, a.value)
        xml.remove_attribute(a.name)
        next
      end
    end

    # recurse
    xml.element_children.each {|e| sanitize_element(e, whitelist, &p) }

    if block_given?
      yield xml
    end
  end

  # Return sanitized HTML.
  #
  # If block is supplied, it will be invoked for each Nokogiri::XML::Element
  # in the sanitized HTML.
  #
  def sanitize(html, whitelist = @whitelist, &p)
    begin
      xml = Nokogiri::HTML(html) {|config| config.noblanks }
      xml = xml.xpath('//html/body').first
    rescue Nokogiri::XML::SyntaxError
      raise WhitewashError, "Invalid XHTML detected: " + $!
    end
    return '' if xml.nil?

    sanitize_element(xml, whitelist, &p)
    xml.children.map {|x| x.to_xhtml}.join
  end

  private

  PATH = [ '/etc/whitewash',
           File.join(RbConfig::CONFIG['datadir'].untaint, 'whitewash'),
           '/usr/local/share/whitewash/' ]

  WHITELIST = 'whitelist.yaml'
end
