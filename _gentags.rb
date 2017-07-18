require 'yaml'
tags = []

tagsdir = "tags"
Dir.mkdir(tagsdir) unless File.exists?(tagsdir)

Dir.glob(File.join('_posts','*.md')).each do |file|
	yaml_s = File.read(file).split(/^---$/)[1]
	yaml_h = YAML.load(yaml_s)
	tags += yaml_h['tags']
end

tags.uniq.each do |tag|
	File.write File.join('tags', "#{tag}.html"), <<-EOF
---
layout: tagpage
tag: #{tag}
permalink: /tags/#{tag}
---
	EOF
end
