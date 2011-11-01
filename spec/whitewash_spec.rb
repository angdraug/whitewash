require File.expand_path('spec/spec_helper')

describe Whitewash do
  it "loads default whitelist" do
    whitelist = Whitewash.default_whitelist
    whitelist.should be_a_kind_of Hash
    whitelist.should include '_css'
  end

  it "drops <html> and <body> elements" do
    w = Whitewash.new
    input = '<html><head></head><body><p>test</p></body>'
    output = w.sanitize(input)
    output.should == '<p>test</p>'
  end

  it "understands fragments with multiple root elements" do
    w = Whitewash.new
    input = '<p>foo</p><p>bar</p>'
    output = w.sanitize(input)
    output.should == '<p>foo</p><p>bar</p>'
  end

  it "removes <script/> element" do
    w = Whitewash.new
    input = '<p>foo <script type="text/javascript" src="test.js">bar</script> buzz</p>'
    output = w.sanitize(input)
    output.should == '<p>foo <![CDATA[bar]]> buzz</p>'
  end

  it "removes onclick attribute" do
    w = Whitewash.new
    input = '<p>foo <span onlick="test()">bar</span> buzz</p>'
    output = w.sanitize(input)
    output.should == '<p>foo <span>bar</span> buzz</p>'
  end

  it "removes background CSS property" do
    w = Whitewash.new
    input = '<p>foo <span style="background: url(//test/t.js)">bar</span> buzz</p>'
    output = w.sanitize(input)
    output.should == '<p>foo <span>bar</span> buzz</p>'
  end

  it "rewrites HTML when supplied with a block" do
    w = Whitewash.new
    input = '<p>foo <img src="in.jpg"/> buzz</p>'
    output = w.sanitize(input) do |xml|
      if xml.name == 'img'
        xml['src'] = 'out.jpg'
      end
    end
    output.should == '<p>foo <img src="out.jpg" /> buzz</p>'
  end

  it "fixes up invalid markup" do
    w = Whitewash.new
    input = '<p>foo <strong><em>bar</strong></em> buzz</p>'
    output = w.sanitize(input)
    output.should == '<p>foo <strong><em>bar</em></strong> buzz</p>'
  end

  # http://ha.ckers.org/xss.html

  it "catches javascript: in img/src" do
    w = Whitewash.new
    input = %q{<IMG SRC=JaVaScRiPt:alert('XSS')>}
    output = w.sanitize(input)
    output.should == %q{<img />}
  end

  it "handles strings with null in the middle" do
    w = Whitewash.new
    input = %q{<IMG SRC=java\0script:alert("XSS")>}
    output = w.sanitize(input)
    output.should == %q{<img />}
  end

  it "handles extra open brackets" do
    w = Whitewash.new
    input = %q{<<SCRIPT>alert("XSS");//<</SCRIPT>}
    output = w.sanitize(input)
    output.should == '<p>alert("XSS");//</p>'
  end

  it "removes remote stylesheet link" do
    w = Whitewash.new
    input = %q{<P><STYLE>@import'http://ha.ckers.org/xss.css';</STYLE></P>}
    output = w.sanitize(input)
    output.should == '<p></p>'
  end

  it "removes XML data island with CDATA obfuscation" do
    w = Whitewash.new
    input = %{<XML ID=I><X><C><![CDATA[<IMG SRC="javas]]><![CDATA[cript:alert('XSS');">]]> </C></X></xml><SPAN DATASRC=#I DATAFLD=C DATAFORMATAS=HTML></SPAN>}
    output = w.sanitize(input)
    output.should == ']]&gt; <span></span>'
  end
end
