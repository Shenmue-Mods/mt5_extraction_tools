#!/usr/bin/env ruby
require 'pry'
require 'sinatra'
require 'builder'
$renders = "#{ENV['HOME']}/Documents/renders"
$source = "#{ENV['HOME']}/Downloads/s2/out"
$repository = "#{ENV['HOME']}/dev/mt5_extraction_tools/"
def cleanup_path r
    r.gsub($source.gsub('/', '_'), '').gsub('_', '/')
end
def png commit, id
    result = "#{$renders}/#{commit}/#{id}.png"
    if File.exist? result
        result
    else
        result = result.gsub(/_([0-9]+)/, '#\1')
        if File.exists? result
            result
        else
            result.sub(/#([0-9]+)/, '_\1')
        end
    end
end
def mt7s
    Dir["#{$source}/**/*.MT7"].map { |a| a.gsub('/', '_').gsub("#", "-sharp-") }
end
def ids
    Dir["#{$renders}/*"].sort_by{ |f| -File.mtime(f).to_i }.map { |r| File.basename(r) }
end
def score id
    fs = mt7s
    i = 0
    missing = []
    fs.each do |f|
        if File.exist? png(id, f).gsub('-sharp-', '#')
            i += 1 
        else
            missing << cleanup_path(f)
        end
    end
    {i: i, n: fs.size, missing: missing}
end
def get_previous id
    _ids = ids.reverse
    i = _ids.index id
    _ids[(i == 0 or i == nil) ? 0 : i - 1]
end
$commits = {}
def describe_commit id
    if $commits[id].nil?
        $commits[id] = eval `git log --format='{date: "%cd", epoch: "%ct", text: "%B"}' -n 1 '#{id}'`
    end
    $commits[id]
end
get '/' do
    builder(format: :html) do |x|
        x.h1 "Renders"
        x.link rel: 'stylesheet', type: 'text/css', href: 'css/style.css'
        x.table do
            _ids = ids
            min = _ids.collect { |r| score(r)[:i] }.min
            _ids.each do |r|
                commit = describe_commit r
                x.tr do
                    x.td { x.a r, href: "/renders/#{r}", class: "commit" }
                    x.td commit[:text]
                    x.td commit[:date]
                    x.td { x.div style: "width:#{((score(r)[:i] - min)/5)}px;", 
                           class: 'count' }
                end
            end
        end
    end
end
get '/renders/:id' do |id|
    builder(format: :html) do |x|
        x.link rel: 'stylesheet', type: 'text/css', href: '/css/style.css'
        x.h1 id
        x.a "..", href: "/"
        x.a "failed list", href: "#failed"
        x.br
        commit = describe_commit id
        x.a "#{commit[:date]}, #{commit[:text]}"
        x.table do
            previous = get_previous id
            x.tr do
                x.th 'name'
                x.th id
                x.th do
                    x.a "previous (#{previous})", href: "/renders/#{previous}"
                end
            end
            x.tr do
                n = score(id)
                p = score(previous)
                delta = n[:i] - p[:i]
                style = delta > 0 ? 'plus' : 'less'
                symbol = delta > 0 ? '+' : '-'
                x.td do 
                    x.a "score ("
                    x.a "#{symbol}#{delta}", class: style
                    x.a "/#{n[:n]})"
                end
                x.td n[:i]
                x.td p[:i]
            end
            mt7s.each do |r|
                x.tr do
                    x.td cleanup_path r 
                    x.td { x.img width: '100%', src: "/render/#{id}/#{r}"}
                    x.td { x.img width: '100%', src: "/render/#{previous}/#{r}"}
                end
            end
            x.tr do
                x.td { x.a('failed list', name: 'failed') }
                x.td do
                    x.ul { score(id)[:missing].each { |m| x.li(m) } }
                end
                x.td do
                    x.ul { score(previous)[:missing].each { |m| x.li(m) } }
                end
            end
        end
    end
end
get '/render/:commit/:id' do |commit, id|
    png = png(commit, id.gsub("-sharp-", "#"))
    File.open(png) { |f| f.read } if File.exist? png
end
